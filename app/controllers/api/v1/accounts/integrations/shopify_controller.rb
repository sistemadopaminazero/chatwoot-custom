class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::BaseController
  include Shopify::IntegrationHelper
  before_action :setup_shopify_context, only: [:orders]
  before_action :fetch_hook, except: [:auth]
  before_action :validate_contact, only: [:orders]

  def auth
    shop_domain = params[:shop_domain]
    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?

    state = generate_shopify_token(Current.account.id)

    auth_url = "https://#{shop_domain}/admin/oauth/authorize?"
    auth_url += URI.encode_www_form(
      client_id: client_id,
      scope: REQUIRED_SCOPES.join(','),
      redirect_uri: redirect_uri,
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def orders
    customers = fetch_customers
    return render json: { orders: [] } if customers.empty?

    orders = fetch_orders(customers.first['id'])
    render json: { orders: orders }
  rescue ShopifyAPI::Errors::HttpResponseError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/shopify/callback"
  end

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'shopify')
  end

  def fetch_customers
    query = []
    query << "email:#{contact.email}" if contact.email.present?
    query << "phone:#{contact.phone_number}" if contact.phone_number.present?

    shopify_client.get(
      path: 'customers/search.json',
      query: {
        query: query.join(' OR '),
        fields: 'id,email,phone'
      }
    ).body['customers'] || []
  end

  def fetch_orders(customer_id)
    orders = shopify_client.get(
      path: 'orders.json',
      query: {
        customer_id: customer_id,
        status: 'any',
        fields: 'id,name,email,created_at,total_price,currency,fulfillment_status,financial_status,fulfillments'
      }
    ).body['orders'] || []

    orders.map { |order| decorate_order(order) }
  end

  def decorate_order(order)
    order.except('fulfillments').merge(
      'admin_url' => "https://#{@hook.reference_id}/admin/orders/#{order['id']}",
      'tracking' => extract_tracking(order['fulfillments'])
    )
  end

  def extract_tracking(fulfillments)
    Array(fulfillments)
      .flat_map { |fulfillment| tracking_entries_for(fulfillment) }
      .uniq { |tracking| [tracking['company'], tracking['number'], tracking['url']] }
  end

  def tracking_entries_for(fulfillment)
    numbers = Array(fulfillment['tracking_numbers'])
    numbers = [fulfillment['tracking_number']].compact if numbers.empty?

    urls = Array(fulfillment['tracking_urls'])
    urls = [fulfillment['tracking_url']].compact if urls.empty?

    entry_count = [numbers.length, urls.length, 1].max

    entry_count.times.filter_map do |index|
      number = numbers[index] || fulfillment['tracking_number']
      url = urls[index] || fulfillment['tracking_url']
      company = fulfillment['tracking_company']

      next if number.blank? && url.blank? && company.blank?

      {
        'company' => company,
        'number' => number,
        'url' => url,
        'shipment_status' => fulfillment['shipment_status'],
        'status' => fulfillment['status']
      }.compact
    end
  end

  def setup_shopify_context
    return if client_id.blank? || client_secret.blank?

    ShopifyAPI::Context.setup(
      api_key: client_id,
      api_secret_key: client_secret,
      api_version: '2025-01'.freeze,
      scope: REQUIRED_SCOPES.join(','),
      is_embedded: true,
      is_private: false
    )
  end

  def shopify_session
    ShopifyAPI::Auth::Session.new(shop: @hook.reference_id, access_token: @hook.access_token)
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Rest::Admin.new(session: shopify_session)
  end

  def validate_contact
    return unless contact.blank? || (contact.email.blank? && contact.phone_number.blank?)

    render json: { error: 'Contact information missing' },
           status: :unprocessable_entity
  end
end

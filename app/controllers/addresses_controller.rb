class AddressesController < ApplicationController
  load_and_authorize_resource
  before_action :set_address, only: [:show, :edit, :update, :order_progress, :download_pass]

  # # GET /addresses
  # # GET /addresses.json
  # def index
  #   @addresses = Address.all
  # end

  # GET /addresses/1
  # GET /addresses/1.json
  def show
    unless @address.button_code.present?      
      unless Rails.env == "test"
        begin
          coinbase = Coinbase::Client.new(ENV['COINBASE_API_KEY'])
          # Disabled pending: https://www.bountysource.com/issues/7423534-coinbase-bug
          # button = coinbase.create_button "Your Order ##{ @address.id }", ENV['PRICE'].to_f, "1 pass for your #{ @address.name } address", "A#{ @address.id }"
          # @address.update button_code: button.button.code
      
          @address.fetch_balance_and_last_transaction!
        rescue OpenSSL::SSL::SSLError
          flash[:error] = "Something went wrong while connecting to Coinbase. Please try again later."
          logger.error "SSL Error with Coinbase for address #{ @address }."
          redirect_to root_path
          return
        end  
         
        
      end
    end
  end
  
  # GET /addresses/new
  def new
    if params[:address]
      @address = Address.new(address_params)
    else
      @address = Address.new
    end
  end

  # GET /addresses/1/edit
  def edit
  end

  # POST /addresses
  def create
    @address = Address.new(address_params)
    
    @address.session_secret = Base64.urlsafe_encode64(SecureRandom.base64(36))

    respond_to do |format|
      if @address.save
        reset_session
        session[:address_secret] = @address.session_secret
        format.html { redirect_to @address, notice: 'Address was found.' }
      else
        format.html { render action: 'new' }
      end
    end
  end

  # PATCH/PUT /addresses/1
  # PATCH/PUT /addresses/1.json
  def update
    respond_to do |format|
      if @address.update(address_params)
        format.html { redirect_to @address, notice: 'Address was found.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @address.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def order_progress
    respond_to do |format|
      format.html {
        render "_order_progress", :layout => nil
      }
    end
  end
  
  def download_pass
    if !@address.paid
      flash[:error] = "We haven't confirmed payment for this address yet."
      redirect_to address_path(@address)
      return
    end
    
    if !@address.download_code
      while 
        @address.download_code = rand(1000000)
        break if Address.where(download_code: @address.download_code).count == 0
      end
      @address.download_code_expires_at = 1.hour.from_now
      @address.save
      
    end
    
    if session[:used_download_code]
      @used_download_code = session[:used_download_code]
      session[:used_download_code] = false
    else
      @used_download_code = false
    end
    
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_address
      @address = Address.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def address_params
      params.require(:address).permit(:base58, :name)
    end
end

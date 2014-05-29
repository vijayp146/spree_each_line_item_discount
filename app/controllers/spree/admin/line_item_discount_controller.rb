
require 'show_line_item_discount'

module Spree
  module Admin
    class LineItemDiscountController < BaseController
      include ShowLineItemDiscount

      def index

        unless params[:order_number].blank?
           order = Spree::Order.find(params[:order_number]) rescue nil
           order = Spree::Order.find_by_number(params[:order_number]) if order.nil?
           if order.nil?
            @result = "Order not found"
           else
             @result = ShowLineItemDiscount.show_discount_for_each_line_items(order)
             p "################"
             p @result
             p "###############"
           end
        end

      end

    end
  end

end
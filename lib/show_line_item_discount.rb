module ShowLineItemDiscount


  def self.show_discount_for_each_line_items(order)
    @result = 0

    no_promotion_action = order.adjustments.first.originator.promotion rescue nil


    ################ no promotions activated
    unless no_promotion_action
      return
    end

    active_promotion = order.adjustments.where(originator_type: Spree::PromotionAction).collect {|e| e if e.eligible == true }.first rescue nil

    unless active_promotion
      p 'No discount from this offer.'
      return
    end

    promotion_action = active_promotion.originator.promotion.actions.first

    unless promotion_action.calculator.preferences.keys.empty?

      keys = promotion_action.calculator.preferences.keys


      if keys.include? :cat1
        @result = number_to_buy_c1(promotion_action, keys, active_promotion)
      end

      if keys.include? :cat2
        @result = number_to_buy_c2(promotion_action, keys, active_promotion)
      end


      if keys.include? :taxon
        @result =  number_to_buy_taxon(promotion_action, keys, active_promotion)
      end

      if keys.include? :flat_percent and keys.include? :cat1
        @result = flat_percent_c1(promotion_action, active_promotion)
      end

      if keys.include? :flat_percent and keys.include? :cat2
        @result = flat_percent_c2(promotion_action, active_promotion)
      end

      if keys.include? :flat_percent and keys.include? :taxon
        @result = flat_percent_taxon(promotion_action, active_promotion)
      end

      if keys.include? :flat_percent and !keys.include? :cat1 and !keys.include? :cat2 and !keys.include? :taxon
        @result = flat_percent(active_promotion)
      end

      @result
    end

  end



  private



  #-------------------------------------------- c1 -----------------------------------------------------------------
  def self.number_to_buy_c1(promotion_action, keys, active_promotion)
    ######### buy one get one offer c1
    order = active_promotion.source
    valid_line_items = []

    if keys.include? :number_to_buy and keys.include? :cat1
      cat1 = promotion_action.calculator.get_preference(:cat1).to_s.split(',').collect(&:strip) rescue []

      order.line_items.each do |line_item|
        flag = false
        line_item.product.taxons.each do |t|
          cat1.each do |c1|
            if t.live? and "t/" + t.parent.parent.permalink == c1
              valid_line_items.push(line_item) if flag == false
              flag = true
              break
            end
            break if flag == true
          end
        end
      end


      sort_line_items = sort_line_items(valid_line_items)
      free_items = get_free_items(sort_line_items.size, sort_line_items, order)


      discount_items = sort_line_items.first(free_items[0])
      non_discount_items = ( free_items[1] - discount_items)
      discount = sort_line_items.first(free_items[0]).sum(&:last)
      buy_one_get_one_result = cal_free_and_paid_each_discount(discount_items, non_discount_items, discount, active_promotion )

      buy_one_get_one_result
    end
  end
  #--------------------------------------------end c1 -----------------------------------------------------------------




  #-------------------------------------------- c2 -----------------------------------------------------------------
  def self.number_to_buy_c2(promotion_action, keys, active_promotion)
    ######### buy one get one offer c2
    order = active_promotion.source
    valid_line_items = []
    if keys.include? :number_to_buy and keys.include? :cat2
      cat2 = promotion_action.calculator.get_preference(:cat2).to_s.split(',').collect(&:strip) rescue []

      order.line_items.each do |line_item|
        flag = false
        line_item.product.taxons.each do |t|
          cat2.each do |c2|

            if t.live? and "t/" + t.parent.permalink == c2
              valid_line_items.push(line_item) if flag == false
              flag = true
              break
            end
            break if flag == true
          end
        end
      end


      sort_line_items = sort_line_items(valid_line_items)
      free_items = get_free_items(sort_line_items.size, sort_line_items, order)

      discount_items = sort_line_items.first(free_items[0])
      non_discount_items = ( free_items[1] - discount_items)
      discount = sort_line_items.first(free_items[0]).sum(&:last)
      buy_one_get_one_result = cal_free_and_paid_each_discount(discount_items, non_discount_items, discount, active_promotion )


      buy_one_get_one_result


    end
  end
  #--------------------------------------------end c2 -----------------------------------------------------------------





  def self.number_to_buy_taxon(promotion_action, keys, active_promotion)
    ######### buy one get one offer taxon
    order = active_promotion.source
    valid_line_items = []
    if keys.include? :number_to_buy and keys.include? :taxon
      taxons = promotion_action.calculator.get_preference(:taxon).to_s.split(',').collect(&:strip) rescue []

      order.line_items.each do |line_item|
        flag = false
        line_item.product.taxons.select('name').map{ |t|
          if taxons.include? t.name
            valid_line_items << line_item
            flag = true
            break
          end
          break if flag = true
        }
      end

      sort_line_items = sort_line_items(valid_line_items)
      free_items = get_free_items(sort_line_items.size, sort_line_items, order)


      discount_items = sort_line_items.first(free_items[0])
      non_discount_items = ( free_items[1] - discount_items)
      discount = sort_line_items.first(free_items[0]).sum(&:last)
      buy_one_get_one_result = cal_free_and_paid_each_discount(discount_items, non_discount_items, discount, active_promotion )


      buy_one_get_one_result



    end

  end


  def self.free_ratio(order)
    promotion_action = order.adjustments.first.originator.promotion.actions.first
    number_to_buy = promotion_action.calculator.get_preference(:number_to_buy)
    number_to_get = promotion_action.calculator.get_preference(:number_to_get)
    number_to_get.to_f / ( number_to_get + number_to_buy )
  end

  def self.get_free_items(number_of_items, sort_line_items, order)
    n = (number_of_items * free_ratio(order)).to_i
    [n, sort_line_items]
  end


  def self.sort_line_items(line_items)
    @obj_arry = []

    line_items.inject([]) {|prices, li|
      each_obj = []
      each_obj.push(li.id)
      each_obj.push(li.price.to_f * li.quantity)
      @obj_arry << each_obj
    }
    obj_arry = @obj_arry.sort {|a, b| a[1] <=> b[1]}
    obj_arry
  end



  def self.cal_free_and_paid_each_discount(discount_items, non_discount_items, discount, active_promotion )
    buy_one_get_one_each_line_item_discount = {}

    discount_items.each do  |discount_item|
      line_item = Spree::LineItem.find(discount_item[0])
      buy_one_get_one_each_line_item_discount[discount_item[0]] =    {:type => "Discount" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => "#{discount_item[1]}" }
    end

    non_discount_items.each do  |non_discount_item|
      line_item = Spree::LineItem.find(non_discount_item[0])
      buy_one_get_one_each_line_item_discount[non_discount_item[0]] = {:type => "Non Discount" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => "#{non_discount_item[1]}" }
    end

    active_promotion.source.line_items.each do  |line_item|
      unless buy_one_get_one_each_line_item_discount.include? line_item.id
        buy_one_get_one_each_line_item_discount[line_item.id] = {:type => "Non Promotion" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => "#{line_item.price}" }
      end
    end

    [buy_one_get_one_each_line_item_discount, {:promotion => {"#{active_promotion.label}" => discount}   }]

  end


  #flat percent
  def self.flat_percent(active_promotion)
    each_line_item_discount = {}
    order = active_promotion.source
    adjustment_total = order.adjustment_total.to_f
    item_total = order.item_total.to_f

    order.line_items.each do |line_item|
      each_line_item_discount[line_item.id] = {:type => "Discount" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => ( (line_item.price.to_f * line_item.quantity) * (adjustment_total.abs/item_total)).round(2) }
    end
    [each_line_item_discount, {:promotion => {"#{active_promotion.label}" => active_promotion.amount.to_f}   }]

  end


  #----------------------- c1 flat percent ---------------------------------
  def self.flat_percent_c1(promotion_action,active_promotion)
    each_line_item_discount = {}
    valid_line_items = []
    order = active_promotion.source
    adjustment_total = order.adjustment_total.to_f

    cat1 = promotion_action.calculator.get_preference(:cat1).to_s.split(',').collect(&:strip) rescue []
    order.line_items.each do |line_item|
      flag = false
      line_item.product.taxons.each do |t|
        cat1.each do |c1|
          if t.live? and "t/" + t.parent.parent.permalink == c1
            valid_line_items.push(line_item) if flag == false
            flag = true
            break
          end
          break if flag == true
        end
      end
    end

    price = []
    valid_line_items.each do |li|
      price << li.price.to_f * li.quantity
    end
    promotion_item_total = price.sum
    valid_line_items.each do |line_item|
      each_line_item_discount[line_item.id] = {:type => "Discount" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => ( (line_item.price.to_f * line_item.quantity) * (adjustment_total.abs/promotion_item_total)).round(2) }
    end

    order.line_items.each do |line_item|
      unless each_line_item_discount.include? line_item.id
        each_line_item_discount[line_item.id] = {:type => "Non Promotion" , :original_amount => (line_item.price.to_f * line_item.quantity) }
      end
    end

    [each_line_item_discount, {:promotion => {"#{active_promotion.label}" => active_promotion.amount.to_f}   }]

  end


  #----------------------- c2 flat percent ---------------------------------
  def self.flat_percent_c2(promotion_action,active_promotion)
    each_line_item_discount = {}
    valid_line_items = []
    order = active_promotion.source
    adjustment_total = order.adjustment_total.to_f

    cat2 = promotion_action.calculator.get_preference(:cat2).to_s.split(',').collect(&:strip) rescue []
    order.line_items.each do |line_item|
      flag = false
      line_item.product.taxons.each do |t|
        cat2.each do |c2|
          if t.live? and "t/" + t.parent.permalink == c2
            valid_line_items.push(line_item) if flag == false
            flag = true
            break
          end
          break if flag == true
        end
      end
    end

    price = []
    valid_line_items.each do |li|
      price << li.price.to_f * li.quantity
    end
    promotion_item_total = price.sum
    valid_line_items.each do |line_item|
      each_line_item_discount[line_item.id] = {:type => "Discount" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => ( (line_item.price.to_f * line_item.quantity) * (adjustment_total.abs/promotion_item_total)).round(2) }
    end

    order.line_items.each do |line_item|
      unless each_line_item_discount.include? line_item.id
        each_line_item_discount[line_item.id] = {:type => "Non Promotion" , :original_amount => (line_item.price.to_f * line_item.quantity) }
      end
    end

    [each_line_item_discount, {:promotion => {"#{active_promotion.label}" => active_promotion.amount.to_f}   }]

  end



  #----------------------- taxon flat percent ---------------------------------
  def self.flat_percent_taxon(promotion_action,active_promotion)
    each_line_item_discount = {}
    valid_line_items = []
    order = active_promotion.source
    adjustment_total = order.adjustment_total.to_f

    taxons = promotion_action.calculator.get_preference(:taxon).to_s.split(',').collect(&:strip) rescue []
    order.line_items.each do |line_item|
      flag = false
      line_item.product.taxons.select('name').map{ |t|
        if taxons.include? t.name
          valid_line_items << line_item
          flag = true
          break
        end
        break if flag = true
      }
    end

    price = []
    valid_line_items.each do |li|
      price << li.price.to_f * li.quantity
    end
    promotion_item_total = price.sum
    valid_line_items.each do |line_item|
      each_line_item_discount[line_item.id] = {:type => "Discount" , :original_amount => (line_item.price.to_f * line_item.quantity), :discount_amount => ( (line_item.price.to_f * line_item.quantity) * (adjustment_total.abs/promotion_item_total)).round(2) }
    end

    order.line_items.each do |line_item|
      unless each_line_item_discount.include? line_item.id
        each_line_item_discount[line_item.id] = {:type => "Non Promotion" , :original_amount => (line_item.price.to_f * line_item.quantity) }
      end
    end

    [each_line_item_discount, {:promotion => {"#{active_promotion.label}" => active_promotion.amount.to_f}   }]

  end


end


# order.adjustments
#335023 = flat percentage
#336058
#336061
#336039 = buy one get one taxon

#336062  -- c1 buy one get one

#336063  -- c2 buy one get one

#331149  -- c1 30% off only t/designers/women
#336067  -- c1 30% off only t/designers/women

#336068  -- c2 35% off only t/designers/women/accessories

#336069  -- taxon 54% off Ivorytagscarves,Pop cult


#336064  -- texon buy one get on
#order = Spree::Order.find(336062)
#ShowLineItems.show_discount_for_each_line_items(order)
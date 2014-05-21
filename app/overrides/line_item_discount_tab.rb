
Deface::Override.new(:virtual_path => "spree/layouts/admin",
                     :name => "admin_line_item_discount",
                     :insert_bottom => "[data-hook='admin_tabs']",
                     :text => "<%= tab :line_item_discount,  :url => '/admin/line_item_discount', :icon => 'icon-preference' %>",
                     :disabled => false)
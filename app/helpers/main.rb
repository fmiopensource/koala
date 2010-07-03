class Main
  helpers do

    # Your helpers go here. You can also create another file in app/helpers with the same format.
    # All helpers defined here will be available across all the application.
    #
    # @example A helper method for date formatting.
    #
    #   def format_date(date, format = "%d/%m/%Y")
    #     date.strftime(format)
    #   end

    # Generate HAML and escape HTML by default.
    def haml(template, options = {}, locals = {})
      options[:escape_html] = true unless options.include?(:escape_html)
      super(template, options, locals)
    end

    # Render a partial and pass local variables or even a collection
    #
    # Example:
    #   != partial :games, :players => @players
    #   != partial :object, :collection => @objects
    def partial(template, *args)
      template_array = template.to_s.split('/')
      template = template_array[0..-2].join('/') + "/_#{template_array[-1]}"
      options = args.last.is_a?(Hash) ? args.pop : {}
      options.merge!(:layout => false)
      if collection = options.delete(:collection) then
        collection.inject([]) do |buffer, member|
          buffer << haml(:"#{template}", options.merge(:layout =>
          false, :locals => {template_array[-1].to_sym => member}))
        end.join("\n")
      else
        haml(:"#{template}", options)
      end
    end
  end
end

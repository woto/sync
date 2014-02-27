module Sync

  module ViewHelpers

    # Surround partial render in script tags, watching for 
    # sync_update and sync_destroy channels from pubsub server
    #
    # options - The Hash of options
    #   partial - The String partial filename without leading underscore
    #   resource - The ActiveModel resource
    #   collection - The Array of ActiveModel resources to use in place of 
    #                single resource
    #
    # Examples
    #   <%= sync partial: 'todo', resource: todo %>
    #   <%= sync partial: 'todo', collection: todos %>
    #
    def sync(options = {})
      channel      = options[:channel]
      partial_name = options.fetch(:partial, channel)
      collection   = options[:collection] || [options.fetch(:resource)]
      refetch      = options.fetch(:refetch, false)

      results = []
      collection.each do |resource|
        if refetch
          partial = RefetchPartial.new(partial_name, resource, channel, self)
        else
          partial = Partial.new(partial_name, resource, channel, self)
        end
        results << "
          <script type='text/javascript' data-sync-id='#{partial.selector_start}'>
            Sync.onReady(function(){
              var partial = new Sync.Partial({
                name:           '#{partial.name}',
                resourceName:   '#{partial.resource.name}',
                resourceId:     '#{resource.id}',
                authToken:      '#{partial.auth_token}',
                channelUpdate:  '#{partial.channel_for_action(:update)}',
                channelDestroy: '#{partial.channel_for_action(:destroy)}',
                selectorStart:  '#{partial.selector_start}',
                selectorEnd:    '#{partial.selector_end}',
                refetch:        #{refetch},
                refetch_url:    '#{url_for(params.merge(action: :refetch))}'
              });
              partial.subscribe();
            });
          </script>
        ".html_safe
        results << partial.render
        results << "
          <script type='text/javascript' data-sync-id='#{partial.selector_end}'>
          </script>
        ".html_safe
      end

      safe_join(results)
    end

    # Setup listener for new resource from sync_new channel, appending
    # partial in place
    #
    # options - The Hash of options
    #   partial - The String partial filename without leading underscore
    #   resource - The ActiveModel resource
    #   scope - The ActiveModel resource to scope the new channel publishes to.
    #           Used for restricting new resource publishes to 'owner' models.
    #           ie, current_user, project, group, etc. When excluded, listens 
    #           for global resource creates.
    # 
    #   direction - The String/Symbol direction to insert rendered partials.
    #               One of :append, :prepend. Defaults to :append
    #
    # Examples
    #   <%= sync_new partial: 'todo', resource: Todo.new, scope: @project %>
    #   <%= sync_new partial: 'todo', resource: Todo.new, scope: @project, direction: :prepend %>
    #  
    def sync_new(options = {})
      partial_name = options.fetch(:partial)
      resource     = options.fetch(:resource)
      scope        = options[:scope]
      direction    = options.fetch :direction, 'append'
      refetch      = options.fetch(:refetch, false)

      if refetch
        creator = RefetchPartialCreator.new(partial_name, resource, scope, self)
      else
        creator = PartialCreator.new(partial_name, resource, scope, self)
      end
      "
        <script type='text/javascript' data-sync-id='#{creator.selector}'>
          Sync.onReady(function(){
            var creator = new Sync.PartialCreator({
              name:         '#{partial_name}',
              resourceName: '#{creator.resource.name}',
              channel:      '#{creator.channel}',
              selector:     '#{creator.selector}',
              direction:    '#{direction}',
              refetch:      #{refetch},
              refetch_url:  '#{url_for(params.merge(action: :refetch))}'
            });
            creator.subscribe();
          });
        </script>
      ".html_safe
    end
  end
end

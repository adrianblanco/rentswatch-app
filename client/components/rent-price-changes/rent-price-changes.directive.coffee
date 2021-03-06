angular.module 'rentswatchApp'
  .directive 'rentPriceChanges', (dashboard, $filter, rate)->
    'ngInject'
    restrict: 'E'
    scope:
      months: "="
    link: (scope, element, attr)->
      new class RentPriceChanges
        TRANSITION_DURATION: 600
        DEFAULT_CONFIG: c3.chart.internal.fn.getDefaultConfig()
        getCurrency: -> $filter('currencySymbol') rate.use()
        getXValues: => _.map(scope.months, 'month')
        generateColumns: =>
          series = [ ['x'].concat do @getXValues ]
          series.push( ['changes'].concat _.map(scope.months, 'avgPricePerSqm') )
          series
        generateXAxis:  =>
          # Return a configuration objects
          type: 'categories'
          categories: do @getXValues
          tick:
            outer: false
            centered: yes
            culling:
              max: 5
            multiline: no
        getMinY: =>
          Math.floor(_.chain(scope.months)
          .map (d)-> Math.max 0, d.avgPricePerSqm - (1.96 * d.stdErr)
          .min()
          .value())
        getMaxY: =>
          Math.ceil(_.chain(scope.months)
          .map (d)-> d.avgPricePerSqm + (1.96 * d.stdErr)
          .max()
          .value())
        generateYAxis: =>
          min = do @getMinY
          max = do @getMaxY
          console.log max
          # Return a configuration objects
          min: min
          max: max
          tick:
            format: (d)=>
              unit = if d is max then ' ' + @getCurrency() + '/m²' else ''
              $filter('number')( $filter('rate')(d), 1) + unit
          padding:
            top: 0
            bottom: 0
        generateColors: =>
          changes: dashboard.fillcolors[0]
        generateChart: =>
          # Destroy existing chart
          if @chart? then do @chart.destroy
          # Generate the chart!
          @chart = c3.generate
            # Enhance the chart with d3
            bindto: element[0]
            interaction:
              enabled: yes
            padding:
              right: 0
              top: 20
            legend:
              show: no
            tooltip:
              show: no
            point:
              show: no
            line:
              connectNull: yes
            transition:
              duration: @TRANSITION_DURATION
            axis:
              x: @generateXAxis()
              y: @generateYAxis()
            grid:
              y:
                show: yes
            data:
              x: 'x'
              type: 'line'
              columns: @generateColumns()
              colors: @generateColors()
          setTimeout @enhanceChart, 1000
        setupAreas: =>
          # Not the first time we create areas
          if @areasGroup? then do @areasGroup.remove
          # Create a D3 elemnt
          @svg = d3.select(element[0]).select('svg')
          # Select the existing c3 chart
          @areasGroup = @svg.select '.c3-chart'
            # Create a group
            .insert 'g', '.c3-chart-lines'
            # Name it accordingly
            .attr 'class', 'd3-chart-areas'
        getArea: =>
          d3.svg.area()
            .x (d, i)=> @chart.internal.x i
            .y0 (d)=> @chart.internal.y(d.avgPricePerSqm - (1.96 * d.stdErr))
            .y1 (d)=> @chart.internal.y(d.avgPricePerSqm + (1.96 * d.stdErr))
        enhanceChart: =>
          # Prepare areas
          do @setupAreas
          # Within the same group... append a path
          @areasGroup
            .append 'path'
            # And bind values to the group
            .datum scope.months
            # Name the path after the current group
            .attr 'class', (d)-> 'd3-chart-area'
            .attr 'd', do @getArea
        constructor: ->
          # Generate the chart
          do @generateChart
          # Refresh graph on currency change
          scope.$watch (-> rate.use() ), @generateChart

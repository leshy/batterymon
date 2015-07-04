#!/usr/bin/livescript
# nocompile

require! {
  helpers: h
  fs: fs
  backbone4000: Backbone
  abstractman: abstractMan
  colors: colors
  underscore: _
}

exec = require('child_process').exec

batState = abstractMan.State.extend4000(
  initialize: ->
    @checkMove()
    @on 'visit', ~> @checkMove()
    @on 'settle', ~>
      console.log colors.green "settled on #{@name}"
      if @settle then @settle()
    

  check: (batstate) ->
    console.log colors.red('no check'), @name, batstate
            
  checkMove: (batstate) ->
    if not batstate then batstate = @root.get 'battery'
    child = @children.find (child) -> child.check(batstate)
    if child
      @changeState child
      true
    else
      @trigger 'settle'
      void
  )


BatAlerter = abstractMan.StateMachine.extend4000(
  name: 'batAlerter'
  bat: 'BAT0'  
  stateClass: batState
  start: 'unknown'

  defaults: {
    battery: { state: 'unknown' } }
    
  initialize: ->
    @env = {}
    @env.full = Number fs.readFileSync '/sys/class/power_supply/BAT0/energy_full'
    @env.perc = @env.full / 100.0

    @update()
    setInterval (~> @update()), 1000
    @on 'change:battery', (model,battery) ~>
      console.log battery
      @state.checkMove(battery)
    
  update: ->
    @set { battery: {
      charge: Math.floor(Number(fs.readFileSync "/sys/class/power_supply/#{@bat}/energy_now") / @env.perc)
      state: (h.trim String fs.readFileSync "/sys/class/power_supply/#{@bat}/status").toLowerCase()
    }}
    
)

state_charging = BatAlerter.defineState 'charging', child: 'unknown', check: ((state) -> state.state is 'charging'), settle: -> notify "Battery is charging"
state_charged = state_charging.defineChild 'charged', children: [ 'discharging', 'unknown' ], check: (state) -> state.state is 'unknown' and state.charge >= 75
state_discharging = state_charging.defineChild 'discharging', children: [ 'charging', 'unknown' ] check: ((state) -> state.state is 'discharging'), settle: -> notify "Battery is discharging"
state_unknown = BatAlerter.defineState 'unknown', children: [ 'charging', 'charged', 'discharging' ], check: (state) -> state.state is 'unknown'

notify = (text) -> exec "notify-send '#{text}'"
blink = (text) -> exec "bash -c '/usr/bin/redshift -o -O 1500; sleep 0.25; /usr/bin/redshift -o -O 3500'"


numberState = (n, options) ->
  state = {
    children: [ 'charging', 'unknown' ]
    check: (state) -> state.charge <= n
    settle: ->
      if options.notify
        if options.notify@@ is String then notify options.notify
        else notify "Battery less then #{n}%"
      if options.blink then blink()
  }
  

state_75 = state_discharging.defineChild '75', numberState(75, notify: true)
state_50 = state_75.defineChild '50', numberState(50, notify: true, blink: true)
state_30 = state_50.defineChild '30', numberState(30, notify: true, blink: true)
state_20 = state_30.defineChild '20', numberState(20, notify: true, blink: true)
state_10 = state_20.defineChild '10', numberState(10, notify: true, blink: true)
state_5 = state_10.defineChild '5', numberState(5, notify: true, blink: true)


batAlerter = new BatAlerter bat: 'BAT0'



Matcher = Struct.new(:dest, :messages)

class IdGenerator
  def initialize
    @c = 0
  end

  def next; @c += 1; end
  def current; @c; end
end

State = Struct.new(:id, :dests )

Transition = Struct.new(:from, :to, :msg)

# Represents a single transition to a state that accespts dest via the
# message :msg
MsgPair = Struct.new(:msg, :dest)

# Represents a state derived from another state at an upper level
# via an MsgPair
DerivedState = Struct.new(:from_id, :msg_pair )

def make_states max_level, matcher_count, matchers
  states = [ State.new(0, matcher_count.times.to_a ) ]
  maker = MakeLevelState.new(max_level, matcher_count, matchers)
  res_states = maker.call( 0, states )
  {states:res_states, transitions: maker.transitions}
end



MakeLevelState = Struct.new( :level, :max_level, :matchers, :transitions, :id_generator ) do


  def initialize max_level, matcher_count, matchers
    super( 0, max_level, matchers, [], IdGenerator.new )
  end

  def call( level, states_bellow_current )
    self.level = level
    states_this_level = states_bellow_current.reduce([],&method(:create_states_reachable_from))
    clean_state_level(states_this_level, transitions)
    if level < max_level - 1
      return states_bellow_current + states_this_level +
        self.call( level + 1, states_this_level )
    else
      return states_this_level
    end
  end


  # Reducer function to create
  def create_states_reachable_from existing_states, state
    # create a flat list of [msg, destination] pairs from the matchers
    msg_pairs =  matchers[level].select{|m| state.dests.include? m.dest }
    # create all the derivable states
    deriveable_states = msg_pairs.map(){|msg_pair| DerivedState.new(state.id, msg_pair)}
    # create the states and transitions reachable via messages
    states_from_this_state = deriveable_states.reduce([], &method(:create_or_reuse_state_for_message))
    # Get a list of destinations that have an any match for the current level
    dests_that_require_messages = deriveable_states.reduce([]){|m, mp| m + [mp.msg_pair.dest]  }
    any_destinations = state.dests.reject {|d| dests_that_require_messages.include? d }
    # add these remaining anys to the current levels "reachable-by-message" states (so that all match the any_matches)
    states_from_this_state.each { |s| s.dests += any_destinations }
    # add the any branch to the tree
    add_new_state_and_transition( states_from_this_state, transitions, state.id, nil, any_destinations )
    # return the reduction result
    existing_states + states_from_this_state
  end


  def create_or_reuse_state_for_message memo, derived_state
    from_state_id = derived_state.from_id
    msg, destination = derived_state.msg_pair.msg, derived_state.msg_pair.dest
    # find any existing transition
    existing_trans = transitions.find {|t| t.from == from_state_id && t.msg == msg  }
    if existing_trans
      existing_state = memo.find{|s| s.id == existing_trans.to}
      fail "No existing state for id #{existing_trans.to}" unless existing_state
      existing_state.dests << destination
    else
      # if there is already a state at this level with the exact same allowances, then reuse that
      add_new_state_and_transition( memo, transitions, from_state_id, msg, [destination] )
    end
    memo
  end


  # Adds a new state and transition using the id generator
  def add_new_state_and_transition state_list, transitions, from_id, msg, destinations
    new_state_id = id_generator.next
    state_list << State.new(new_state_id, destinations )
    self.transitions << Transition.new(from_id, new_state_id, msg)
  end


  # Cleanup
  # -------

  # Merges duplicate states on the same level and updates the transitions.
  def clean_state_level states_this_level, transitions
    # Find any duplicates and get the id->dupe_ids pairs
    dupe_ids = states_this_level.map do |s|
      [s.id, states_this_level.select{|sl| sl.dests == s.dests && sl.id != s.id }.map(&:id)]
    end
    # remove the non-dupes (with empty dupe ids)
    dupe_ids.reject!{|d| d[1].empty? }
    # reject dupes where the dupe id is smaller the the original id (aka. flips)
    dupe_ids.reject! {|d| d[1].any? {|a| a < d[0]} }
    # re-link the transitions
    dupe_ids.each do |dupe|
      original_id = dupe[0]
      dupes = dupe[1]
      transitions.select{|t| dupes.any?{|did| t.to == did }}.each{|t| t.to = original_id }
      states_this_level.reject! {|s| dupes.include?(s.id)}
    end
  end


end


res = make_states( 3, 5, [
  [MsgPair.new(0,0), MsgPair.new(1, 0), MsgPair.new(1,1), MsgPair.new(1,2) ],
  [MsgPair.new("start", 1), MsgPair.new("start", 2), MsgPair.new("end", 2), MsgPair.new("start", 3), MsgPair.new("click", 3)],
  [MsgPair.new(0xfe, 4), MsgPair.new(0xff, 4)],
] )


puts "digraph {"
res[:states].each do |s|
  puts "  s#{s.id} [label=#{(" ##{s.id}\n #{s.dests.inspect}").inspect}]"
end

res[:transitions].each do |t|
  puts "  s#{t.from} -> s#{t.to} [label=#{t.msg ? t.msg.inspect.inspect : '*'.inspect}]"
end

puts "}"

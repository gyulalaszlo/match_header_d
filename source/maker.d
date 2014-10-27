import std.array;
import std.functional;
import std.range;
import std.traits;
import std.typecons;
import std.algorithm;

import std.string;

import detail;
import matcher_automata;

@safe:

/// Packs the state for the making the states and transitions
struct MakeLevelState(uint max_level, MatcherList) {
  uint matcherCount;
  MatcherList matchers;

  IdGenerator!uint idGenerator;

  TransitionList!(max_level-1, MatcherList) transitions;

  this( uint _matcherCount, MatcherList _matchers ) {
    matcherCount = _matcherCount;
    matchers = _matchers;
  }

  auto opCall()
  {
    auto states = [ State(0, iota(matcherCount).array )];
    //auto maker = MakeLevelState!(max_level, MatcherList)( matcher_count, matchers );
    //debug writefln("result=%s", maker.call!0( states ));
    auto statesOut = call!0(states);
    return MatcherAutomata!(max_level, MatcherList)( states ~ statesOut, transitions );
  }


  auto call( uint level)( State[] statesBellowCurrent )
  {
    State[] statesThisLevel;
    // create the states and transitions for this level
    statesThisLevel = statesThisLevel.reduce!((m, s) => createStatesReachableFrom!(level)(m,s))( statesBellowCurrent );
    // make sure the destinations are sorted in the state so the results of matching
    // are deterministic and can be tested
    foreach(s; statesThisLevel) { s.dests.sort(); }

    // Merge & clean up the tree
    cleanStateLevel!(level)( statesThisLevel, transitions[level] );

    // recurse if necessary
    static if (level < max_level - 1 ) {
      return join( [statesThisLevel, call!(level+1)( statesThisLevel )]);
    } else {
      return statesThisLevel;
    }
  }



  ///  Creates all states and transitions a level bellow state that are reachable from state.
  auto createStatesReachableFrom(uint level)( State[] existingStates, State state )
  {
    alias MsgT = LevelMsgT!(level, MatcherList);
    // find all the message transitions available from state
    auto msg_pairs = matchers[level].filter!((a) => state.dests.canFind(a.dest))();
    // create all the derivable states
    auto deriveableStates = msg_pairs.map!(mp => DerivedState!MsgT(state.id, mp) );

    // create all the states reachable via messages on the current level
    State[] statesFromThisState;
    statesFromThisState = statesFromThisState.reduce!((m,s) => createOrReuseStateForMessage!(level,MsgT)(m,s))(deriveableStates);

    // Get a list of destinations that have an any match for the current level
    uint[] destsThatRequireMessages;
    destsThatRequireMessages = destsThatRequireMessages.reduce!((m,a) => m ~ a.msg_pair.dest)(deriveableStates);

    // Get a list of destinations that are reachable from the parent state
    // but have no message specified for the current level, so we need to add them
    // as reachable for each message state
    auto anyDestinations = state.dests.dup.remove!((d) => destsThatRequireMessages.canFind(d));
    foreach(ref s; statesFromThisState) { s.dests ~= anyDestinations; }

    // And finally add the state and transition to match any incoming input
    addNewState( statesFromThisState, transitions[level], state.id, Nullable!MsgT(), anyDestinations  );

    return existingStates ~ statesFromThisState;
  }


  auto createOrReuseStateForMessage(uint level, MsgT)(
      State[] memo, const DerivedState!MsgT derivedState )
  {
    alias MsgT = LevelMsgT!(level, MatcherList);
    // preload
    auto fromStateId = derivedState.from;
    auto msg = derivedState.msg_pair.msg;
    auto destination = derivedState.msg_pair.dest;
    // find any existing transtition so we can find the state to reuse if possible
    auto existingTransition = transitions[level].filter!((t)=> t.from == fromStateId && t.msg == msg );

    if (existingTransition.empty)
    {
      addNewState!MsgT( memo, transitions[level], fromStateId, Nullable!MsgT(msg), [destination] );
    }
    else
    {
      auto existingTransId = existingTransition.front.to;
      auto existingStates = memo.filter!((s) => s.id == existingTransId);
      assert( !existingStates.empty );
      existingStates.front.dests ~= [destination];
    }
    return memo;
  }


  /// Common functionnality for adding a state and a transition from a parent state.
  void addNewState(MsgT)(
      ref State[] stateList, ref Transition!MsgT[] transitions,
      uint fromStateId, Nullable!MsgT msg, uint[] destinations )
  {
      // create a new state
      auto newStateId = idGenerator.next();
      // TODO: do proper growth here
      stateList ~= State(newStateId, destinations);
      transitions ~= Transition!MsgT(fromStateId, newStateId, msg );
  }


  /// Merges duplicate states on the same level and updates the transitions.
  void cleanStateLevel(uint level, MsgT)( ref State[] states, ref Transition!MsgT[] transitions )
  {
    // find any duplicates and get the id->duplicateIds pairs
    auto matchingStates = states.map!((s) => tuple(s.id, states.filter!(sl =>
            sl.dests == s.dests && sl.id != s.id
            ).map!"a.id" ));

    auto duplicateStates = matchingStates.filter!(a => !a[1].empty);
    // remove possible dupe ids

    // reject dupes where the dupe id is smaller the the original id (aka. flips)
    auto dupes = matchingStates.filter!(a => a[1].any!(b => b < a[0] ));


    // re-link the transitions
    foreach(dupe; dupes) {
      auto originalId = dupe[0];
      auto dupeIds = dupe[1].array;
      auto transitionsToRewire = transitions.filter!(t => dupeIds.any!( did=> (t.to == did)));
      foreach(ref t; transitionsToRewire) { t.to = originalId; }

      removeFromStates( states, dupeIds);
    }
  }

  /// Using std.algorithms.remove is unsafe so this is refactored here
  @trusted void removeFromStates(States, IdList)( ref States states, in IdList ids )
  {
    auto cleanedStates = states.remove!(s => ids.any!(did => did == s.id ));
    states.length = cleanedStates.length;
  }
}

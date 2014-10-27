
struct NaiveAutomaton(uint maxLevel, Description) {
  import std.algorithm;

  Description d;

  this( Description d ) { this.d = d; }

  ///
  uint[] match(MatchedT)( MatchedT data )
  {
    return progressFrom!0(0, data );
  }


  uint[] progressFrom(uint level, MsgTuple)( uint stateId, MsgTuple msgPack )
  {
    static if (level == maxLevel) {
      auto possibleEndState = d.states.filter!(s => s.id == stateId );
      assert( !possibleEndState.empty );
      return possibleEndState.front.dests;
    } else {
      auto msg = msgPack[level];
      // try to find message transitions
      auto transitionsFromThis = d.transitions[level].filter!(t => t.from == stateId );
      auto msgTransitions = transitionsFromThis.filter!(t => !t.msg.isNull );
      foreach(transition; msgTransitions) {
        if (msg == transition.msg ) { return progressFrom!(level + 1)( transition.to, msgPack ); }
      }
      // use the any path if none of the message paths match
      auto anyTransition = transitionsFromThis.filter!(t => t.msg.isNull );
      assert( !anyTransition.empty );
      return progressFrom!(level + 1 )( anyTransition.front.to, msgPack );
    }
  }
}

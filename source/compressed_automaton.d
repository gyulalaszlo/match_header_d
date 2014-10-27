@safe:

struct CompressedAutomaton(uint maxLevel, Description) {
  import std.algorithm;
  import std.typecons;
  import std.range;

  import detail;

  static assert(maxLevel >= 2);

  struct DeciderState(MsgT) {
    uint id;
    /// The next state if no matching messages are found
    uint nextOnAny;
    /// The next state depending on the message we get
    uint[MsgT] nextOnMsg;
  }


  alias DeciderT( uint level, MatcherList ) = DeciderState!( LevelMsgT!(level,MatcherList));
  ;

  // A list of types matching the transition type for each level so we have a way to store them
  template DeciderListT(uint level, MatcherList, KeyT=uint) {
    static if(level == 0) {
      alias DeciderListT = DeciderT!( level, MatcherList) [KeyT];
    } else {
      alias DeciderListT = TypeTuple!( DeciderListT!(level-1, MatcherList), DeciderT!(level,MatcherList)[KeyT]);
    }
  }


  struct FinalState { uint id; uint[] dests; }

    DeciderListT!(maxLevel-1, Description.DescriptionT) deciders;
    FinalState[uint] finalStates;

    this( ref Description d ) {
      compressLevel!0(d);
    }


  auto compressLevel(uint level)( ref Description d ) {
    static if( level == maxLevel) {
      uint[] stateIds;
      auto stateIdsThisLevel = stateIds.reduce!((m,a) => m ~= a.to)(d.transitions[level-1]).uniq;
      auto statesThisLevel = d.states.filter!(s => stateIdsThisLevel.any!(id=> id == s.id ));
      foreach(s;statesThisLevel) { finalStates[s.id] = FinalState(s.id, s.dests); }
    } else {
      uint[] stateIds;
      auto stateIdsThisLevel = stateIds.reduce!((m,a) => m ~= a.from)(d.transitions[level]).uniq;
      auto statesThisLevel = d.states.filter!(s => stateIdsThisLevel.any!(id=> id == s.id ));
      auto transitionsFromThisLevel = statesThisLevel.map!( s => d.transitions[level].filter!(t => t.from == s.id  ));
      alias MsgT = Description.MsgT!(level);
      foreach(st; zip(statesThisLevel, transitionsFromThisLevel)) {
        uint anyTransId;
        uint[MsgT] msgMap;
        foreach(t; st[1]) {
          if (!t.msg.isNull) msgMap[t.msg] = t.to;
          else anyTransId = t.to;
        }
        auto stateId = st[0].id;
        deciders[level][ stateId ] = DeciderState!(MsgT)(stateId, anyTransId, msgMap );
      }
      compressLevel!(level+1)(d);
    }
  }


  ///
  uint[] match(MatchedT)( MatchedT data )
  {
    return progressFrom!0(0, data );
  }


  uint[] progressFrom(uint level, MsgTuple)( uint stateId, MsgTuple msgPack )
  {
    static if (level == maxLevel) {
      auto s = (stateId in finalStates );
      assert( s !is null );
      return s.dests;
    } else {
      auto s = (stateId in deciders[level]);
      assert( s !is null );
      auto t = ( msgPack[level] in s.nextOnMsg);
      if (t is null) {
        return progressFrom!(level + 1 )( s.nextOnAny, msgPack );
      } else {
        return progressFrom!(level + 1 )( *t, msgPack );
      }
    }
  }
}

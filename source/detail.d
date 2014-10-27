import std.typecons;
import std.typetuple;
import std.string;


@safe:

struct IdGenerator(T) {
  T id;
  T next() { return ++id; }
  T current() { return id; }
}

template ArrayBaseType(A : E[],E) { alias E ArrayBaseType; }
template NullableBaseType(A : Nullable!E,E) { alias E NullableBaseType; }


/// A state in the output state graph
struct State {
  /// The id of this state
  uint id;

  /// A list of destinations reachable from this state
  uint[] dests;
}


/// A transition between the states from and to triggered
/// by msg.
struct Transition(Msg) {
  alias MsgType = Msg;
  uint from, to;
  Nullable!Msg msg;

  /// This override is needed because of Nullable
  string toString() {
    return msg.isNull ?
      format("Transition:{ %s -> %s on *}", from, to) :
      format("Transition:{ %s -> %s on '%s'}", from, to, msg);
  }
}

/// Represents a single transition to a state that accespts dest via the
/// message :msg
struct MsgPair(Msg) { alias Type = Msg; Msg msg; uint dest; }


// Represents a state derived from another state at an upper level
// via an MsgPair
struct DerivedState(Msg) { alias MsgType = Msg; uint from; MsgPair!(Msg) msg_pair; }

// The message type for the current layer
alias LevelMsgT(uint level, MatcherList) = ArrayBaseType!(MatcherList.Types[level]).Type;

// The transition type for a level in the matcher list tuple
alias TransitionType(uint level, MatcherList) = Transition!(LevelMsgT!(level,MatcherList));

// A list of types matching the transition type for each level so we have a way to store them
template TransitionListT(uint level, MatcherList) {
  static if(level == 0) {
    alias TransitionListT = TransitionType!(level,MatcherList)[];
  } else {
    alias TransitionListT = TypeTuple!( TransitionListT!(level-1, MatcherList), TransitionType!(level,MatcherList)[] );
  }
}

alias TransitionList(uint level, MatcherList) = Tuple!(TransitionListT!(level, MatcherList));



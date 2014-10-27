import std.algorithm;
import std.typecons;
import std.stdio;
import std.range;
import detail;
import std.array;
import std.string;

import naive_automaton;

@safe:

/// The output from make
struct MatcherAutomata(uint maxLevel, MatcherList) {
  State[] states;
  TransitionList!(maxLevel-1, MatcherList) transitions;

  alias DescriptionT = MatcherList;
  alias MsgT(uint level) = NullableBaseType!(typeof(transitions[level][0].msg));

  auto getMatcher(alias AutomatonType=NaiveAutomaton)() {
    return AutomatonType!(maxLevel, MatcherAutomata!(maxLevel, MatcherList))( this );
  }

}

/// Returns a DOT graph as a string representing the states and transitions of the
/// automata
string toDot(Automata)( ref Automata a )
{
  auto app = appender!string();
  app.put("digraph {\n");

  foreach(ref s; a.states) {
    app.put(format("  s%s [label=\"#%s\\n%s\"];\n", s.id, s.id, s.dests ));
  }

  foreach(transitionLevel; a.transitions)
    foreach(t; transitionLevel)
      if (t.msg.isNull)
        app.put(format("  s%s -> s%s [label=\"*\"];\n", t.from, t.to));
      else
        app.put(format("  s%s -> s%s [label=\"%s\"];\n", t.from, t.to, t.msg ));


  app.put("}");
  return app.data;
}


// ---------------------------------------------------










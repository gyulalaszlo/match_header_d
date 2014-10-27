import detail;
import std.array;
import std.string;

/// The output from make
struct MatcherAutomata(uint max_level, MatcherList) {
  State[] states;
  TransitionList!(max_level-1, MatcherList) transitions;

  /// 
  uint[] match(MatchedT)( MatchedT data )
  {
    uint[] matched = [];
    for(uint level = 0; level < max_level; ++level ) {
      if (level == max_level) { return matched; }
      level++;
    }
    return matched;
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


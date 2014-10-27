import maker;
import detail;
import matcher_automata;
import compressed_automaton;
@safe:

/// Creates a list of states and transitions for the given matcher list
///
/// max_level: the depth (the number of consecutive fields)
/// matcher_count: the number of matchers for the output
auto makeStates( MatcherList )( uint matcher_count, MatcherList matchers )
{
  enum maxLevel = MatcherList.length;
  auto maker = MakeLevelState!(maxLevel, MatcherList)( matcher_count, matchers );
  return maker();
}





@trusted:
///
unittest {
  import std.typecons;
  import std.string;
  import std.stdio;
  import std.file;
  import std.datetime;
  import std.functional;
  import std.conv;

  auto a = makeStates( 5, tuple(
      [MsgPair!uint(0,0u), MsgPair!uint(1, 0u), MsgPair!uint(1,1u), MsgPair!uint(1,2u) ],
      [MsgPair!string("start", 1), MsgPair!string("start", 2), MsgPair!string("end", 2), MsgPair!string("start", 3), MsgPair!string("click", 3)],
      [MsgPair!char('c', 4), MsgPair!char('d', 4)],
      [MsgPair!int(99, 1), MsgPair!int(0, 2)],
      ));


  alias Header = Tuple!( uint, string, char, int);
  auto matcher = a.getMatcher();
  auto matcher2 = a.getMatcher!(CompressedAutomaton)();


  void benchDispatch1(MatcherT)( ref MatcherT matcher ) {
    assert( matcher.match( Header(99u, "hello", 'z', 87 ) ) == [] );
    assert( matcher.match( Header(99u, "hello", 'c', 42 ) ) == [4] );
    assert( matcher.match( Header(1, "start", 'c', 99 ) ) == [0,1,3,4] );
  }
  void benchDispatchNormal() { benchDispatch1(matcher); }
  void benchDispatchCompressed() { benchDispatch1(matcher2); }

  //auto r = benchmark!(partial!(benchDispatch1,matcher))(10_000);
  auto r = benchmark!(
      benchDispatchNormal , benchDispatchCompressed
      )(10_000);
  writefln(" bench Normal: %s  ", to!Duration(r[0]));
  writefln(" bench Compressed: %s  ", to!Duration(r[1]));


  // Debug using the DOT export function
  if (false) {
    std.file.write( "test.dot", a.toDot() );
  }
}

import std.stdio;
import std.string;

import std.typecons;

import maker;
import detail;
import matcher_automata;

import std.file;

/// Creates a list of states and transitions for the given matcher list
///
/// max_level: the depth (the number of consecutive fields)
/// matcher_count: the number of matchers for the output
auto makeStates( uint max_level, MatcherList )( uint matcher_count, MatcherList matchers )
{
  auto maker = MakeLevelState!(max_level, MatcherList)( matcher_count, matchers );
  return maker();
}






unittest {
  auto a = makeStates!(3)( 5, tuple(
      [MsgPair!uint(0,0u), MsgPair!uint(1, 0u), MsgPair!uint(1,1u), MsgPair!uint(1,2u) ],
      [MsgPair!string("start", 1), MsgPair!string("start", 2), MsgPair!string("end", 2), MsgPair!string("start", 3), MsgPair!string("click", 3)],
      [MsgPair!char('c', 4), MsgPair!char('d', 4)],
      ));


  alias Header = Tuple!( uint, string, char);
  assert( a.match( Header(99u, "hello", 'z' ) ) == [] );
  //assert( a.match( Header(99u, "hello", 'c' ) ) == [4] );
  std.file.write( "test.dot", a.toDot() );
}

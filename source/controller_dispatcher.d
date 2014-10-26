import std.stdio;
import std.array;
import std.range;
import std.traits;
import std.algorithm;
import murmurhash3;

import std.typecons;
import std.typetuple;

//template Tuple(E...) {
  //alias Tuple = E;
//}

template SlicesOf(E, EL...) {
  static if(EL.length == 0) {
    alias SlicesOf = TypeTuple!(E[]);
  }
  else {
    alias SlicesOf = TypeTuple!( TypeTuple!(E[]), SlicesOf!(EL));
  }
}


unittest {
  alias F = Tuple!(ulong, uint, uint, uint);

  alias T = SlicesOf!(F.Types);
  alias S = Tuple!(T);

  static assert( is(S.Types[0] == ulong[] ));
  static assert( is(S.Types[1] == uint[] ));
  static assert( is(S.Types[2] == uint[] ));
  static assert( is(S.Types[3] == uint[] ));

  auto s = S([1],[2,3,4],[0xfe, 0xff],[]);
  assert( s[0] == [1] );
  assert( s[1] == [2,3,4] );
  assert( s[2] == [0xfe,0xff] );
}

template ArrayBaseType(A : E[],E)
{
  alias E ArrayBaseType;
}

auto makeTable(T)( in T[] s )
  if (isTuple!(T))
{
  alias WithIdT = Tuple!( size_t, const(T) );
  auto withIds = iota(s.length).map!(i => WithIdT(i, s[i])).array();
  return makeTableLevel!(0)(withIds);
}

struct MatcherPair(T) {
  const(T) msg;
  const(size_t) id;
};


struct LevelData(T) {
  /// ids that match any input
  size_t[] any;

  MatcherPair!(T)[] pairs;

};

auto makeTableLevel(uint L, TWithId)( in TWithId[] s )
  if (isTuple!(TWithId) && isTuple!(TWithId.Types[1]))
{
  // figure out thiis levels messages type
  alias T = TWithId.Types[1];
  alias LT = ArrayBaseType!(T.Types[L]);

  alias MT = Tuple!(const(size_t),  const(LT[]) );
  MT[] messagesStart = [];
  auto messages = reduce!((memo,a) => memo ~ MT( a[0], a[1][L]) )( messagesStart, s);

  alias MMT = Tuple!( const(size_t), const(LT));
  auto msgToId = messages.map!(m=> m[1].map!(a => MatcherPair!(LT)(a, m[0])) );

  auto msgCounts = messages.map!(m=> tuple(m[0], m[1].length) );

  LevelData!(LT) l;
  l.any = reduce!((a,b) => a ~ b)( l.any, msgCounts.filter!(m=> m[1] == 0).map!("a[0]") );
  l.pairs = msgToId.join();

  writefln("l[%s] = %s", L, l);

  static if (L == T.length - 1) {
    // last element
    return tuple(l);
  } else {
    return tuple(l, makeTableLevel!(L+1)(s).expand );
  }
}


struct Automata {
  int id;
};

auto buildAutomata(TableTuple)( TableTuple t ) {
  Automata a;
  return buildAutomataLevel!0(t,a);
}

auto buildAutomataLevel( uint L, TableTuple)(TableTuple t, ref Automata a ) {
  writefln("---- Automata level %s -- %s", L, a );
  auto thisLevel = t[L];

  foreach(pair; thisLevel.pairs) {
    writefln(" state:%s requires:%s when '%s'", a.id, pair.id, pair.msg );
    a.id++;
  }

  static if (L == TableTuple.length - 1) {
    return 1;
  } else {
    return buildAutomataLevel!(L+1)(t, a) + 1;
  }
}


unittest {
  //auto a = [];
  //auto b = [0];


  alias F = Tuple!(uint, string, int);
  alias TS = SlicesOf!(F.Types);
  alias T = Tuple!(TS);

  auto t = makeTable([
      T( [0,1], [], []),
      T( [1], ["start"], []),
      T( [], ["start", "click"], []),
      T( [], [], [0xfe, 0xff])
      ]);
  writefln("-------\nc = %s", t);


  auto automata = buildAutomata( t );
}




/*
/// Creates a matcher
DispatchSlot!(Size,T...) makeMatcher(uint Size, uint Idx, T...)( const(T...)[] matches... ) {
  DispatchSlot!(Size,T...) slot;
  slot[Idx] = matches.dup;
  return slot;
}

///
unittest {
  auto dispatch_slot1 = makeMatcher!(1, 0, uint)( 1, 2, 3 );
  assert( dispatch_slot1[0].length == 3);
  assert( dispatch_slot1[0][0] == 1);
  assert( dispatch_slot1[0][1] == 2);
  assert( dispatch_slot1[0][2] == 3);
}


///
DispatchSlot!(Size,T) makeStringMatcher(uint K, uint Size, uint Idx, T)( string[] matches... ) {
  DispatchSlot!(Size,T) slot;
  slot[Idx] = array( map!( a => stringHash32!(K)(a))(matches) );
  return slot;
}

///
unittest {
  enum K = 42;
  alias hasDataType = makeStringMatcher!(K,3,0,uint);
  alias hasPanelType = makeStringMatcher!(K,3,1,uint);

  auto slot1 = hasDataType("MkzPanelMouseEvent");
  assert( slot1.length == 3 );
  assert( slot1[0].length == 1 );
  assert( slot1[1].length == 0 );
  assert( slot1[2].length == 0 );
  assert( slot1[0][0] == stringHash32!(K)("MkzPanelMouseEvent") );

  auto sourceNames = ["ui/panels/tab_bar.panel", "ui/panels/tab_button.panel"];
  auto slot2 = hasPanelType( sourceNames[0], sourceNames[1]);
  assert( slot2.length == 3 );
  assert( slot2[0].length == 0 );
  assert( slot2[1].length == 2 );
  assert( slot2[2].length == 0 );
  assert( slot2[1][0] == stringHash32!(K)(sourceNames[0]) );
  assert( slot2[1][1] == stringHash32!(K)(sourceNames[1]) );
}


auto combine(uint Size, T)( const(T[][Size])[] slots...)
{
  return array( map!( i => join(map!(s=>s[i])( slots )))( iota(0,Size)) );
}

///
unittest {
  enum K = 42;
  alias hasDataType = makeStringMatcher!(K,3,0,uint);
  alias hasPanelType = makeStringMatcher!(K,3,1,uint);

  auto slot1 = hasDataType("MkzPanelMouseEvent");
  auto sourceNames = ["ui/panels/tab_bar.panel", "ui/panels/tab_button.panel"];
  auto slot2 = hasPanelType( sourceNames[0], sourceNames[1]);

  auto slot3 = combine(slot1, slot2);
  writefln("slot3=%s", slot3);
  assert( slot3.length == 3 );
  assert( slot3[0].length == 1 );
  assert( slot3[1].length == 2 );
  assert( slot3[2].length == 0 );
  assert( slot3[0][0] == stringHash32!(K)("MkzPanelMouseEvent") );
  assert( slot3[1][0] == stringHash32!(K)(sourceNames[0]) );
  assert( slot3[1][1] == stringHash32!(K)(sourceNames[1]) );
}



auto makeTable(uint Size,T)( in T[][Size][] table )
{

  //auto mapfn = (auto t) {
    //writefln("t:%s", t);
    //return t;
  //};
  iota(Size).map!((auto t) {

    writefln("t:%s", t);
    return t;
      });
}


///
unittest {

  enum K = 42;
  alias hasDataType = makeMatcher!(3,0,string);
  alias hasPanelType = makeMatcher!(3,1,string);
  alias hasName = makeMatcher!(3,2, string);

  auto slot1 = combine(
      hasDataType("MkzPanelMouseEvent"),
      hasPanelType( "ui/panels/tab_bar.panel", "ui/panels/tab_button.panel")
      );

  auto slot2 = combine(
      hasDataType("MkzPanelMouseEvent"),
      hasPanelType( "ui/panels/tab_button.panel"),
      hasName("main_tab_panel")
      );

  auto slot3 = combine(hasPanelType( "ui/panels/tab_button.panel"));


  auto attribs = [ slot1, slot2, slot3 ];

  auto transitionTable = makeTable!(3,string)( attribs );

}


uint stringHash32(uint K)( string s ) {
  return murmurHash3_x86_32(cast(ubyte[])s, K);
}

///
unittest {
  enum K = 0x3A8EFA67;
  enum test = stringHash32!(K)("test");
  pragma(msg, test);
  assert(test == 395530395, "murmurHash3_x86_32 failed with \"test\" and 0x3A8EFA67");
}
*/

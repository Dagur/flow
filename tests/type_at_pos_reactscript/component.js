component Foo(foo: number) { return null; }
//        ^
component Bar(bar: string) renders number { return 3; }
//        ^
component Baz(foo: number) renders? number { return 3; }
//        ^
component Qux(bar: string) renders* number { return 3; }
//        ^
component Poly<T> (foo: T) {return null};
//        ^
type PolyElementTypeApp = Poly<string>;
//        ^
type ConcretizedPolyComponent = Poly<string> extends React$Element<infer C> ? C : empty;
//        ^

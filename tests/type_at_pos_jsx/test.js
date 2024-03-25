// @flow

import * as React from "react";

declare function Foo(props: { x: number }): React.Node;

(<Foo x />);
//    ^

(<Foo x="" />);
//    ^

(<Foo x={""} />);
//    ^

(<Foo x={0} />);
//    ^

(<Foo key={0} />);
//    ^

(<Foo ref={0} />);
//    ^

declare function Poly<T>(props: { x: T }): React.Node;

(<Poly<_> x={0} />);
//     ^

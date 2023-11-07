// @flow

declare function f(x: {p: string}): number;
declare function f(x: mixed): string;

declare var x: {[K]: string}; // NB: `K` defined below
var ret = f(x); // ok, should match case 2
ret as empty; // err, string ~> empty (matched case 2)

type K = number;

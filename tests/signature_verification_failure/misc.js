//@flow

import * as React from 'react';

export var a: $TEMPORARY$number<'a'> = 42;

export var b: $TEMPORARY$number<1, 1> = 42;

export const c = {['a' + 'b']: 42};

export const d = [...c];

export const e = (d += d);

export const f = class {};

// export const u = 42n; TODO: type sig for bigints

export const w = /foo/;

export const x = <foo />;

function testit(arg: any): boolean %checks {
  return arg as boolean;
}

export const g = testit;

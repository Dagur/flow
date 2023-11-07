//@flow
{
  // Omit Tests
  type Exclude<T, U> = T extends U ? empty : T;

  type Omit<O: {...}, Keys: $Keys<O>> = {
    [key in Exclude<$Keys<O>, Keys>]: O[key],
  };

  type O = {
    foo: number,
    bar: number,
    baz: number,
  };

  declare const noFoo: Omit<O, 'foo'>;
  noFoo.foo = 3; // ERROR!
  noFoo as {bar: number, baz: number}; // OK!

  declare const noFooOrBar: Omit<O, 'foo' | 'bar'>;
  noFooOrBar as {baz: number}; // OK!

  declare const noKeysBad: Omit<O, string>; // ERROR! string is not a subtype of $Keys<O>
  noKeysBad as {};

  declare const noKeysGood: Omit<O, 'foo' | 'bar' | 'baz'>;
  noKeysGood as {}; // OK!

  declare function omit<O: {...}, Keys: $Keys<O>>(
    o: O,
    ...$ReadOnlyArray<Keys>
  ): Omit<O, Keys>;
  // KP: We need proper natural inference to make this work with no annotations
  const noBarOrBaz = omit(
    {foo: 3, bar: 3, baz: 3},
    'bar' as 'bar',
    'baz' as 'baz',
  );
  noBarOrBaz as {foo: number}; // OK!
  noBarOrBaz.foo as number; // OK!
  noBarOrBaz.foo = 3; // OK!

  declare function omitInput<O: {...}, Keys: $Keys<O>>(
    o: O,
    x: Omit<O, Keys>,
    ...$ReadOnlyArray<Keys>
  ): void;
  const noIssues = omitInput({foo: 3, bar: 3}, {bar: 3}, 'foo' as 'foo');
  const badCall = omitInput({foo: 3, bar: 3}, {foo: 3}, 'foo' as 'foo'); // ERROR 2x
}

{
  // Pick Tests
  type Pick<O: {...}, Keys: $Keys<O>> = {[key in Keys]: O[key]};

  type P = {
    foo: number,
    bar: number,
    baz: number,
  };

  declare const onlyFoo: Pick<P, 'foo'>;
  onlyFoo.bar; // ERROR!
  onlyFoo as {foo: number}; // OK!

  declare const fooAndBaz: Pick<P, 'foo' | 'baz'>;
  fooAndBaz as {foo: number, baz: number}; // OK!

  declare function pick<O: {...}, Keys: $Keys<O>>(
    o: O,
    ...$ReadOnlyArray<Keys>
  ): Pick<O, Keys>;
  const picked = pick({foo: 3, bar: 3}, 'foo');
  picked as {foo: number};

  declare function pickInput<O: {...}, Keys: $Keys<O>>(
    o: O,
    x: Pick<O, Keys>,
    ...$ReadOnlyArray<Keys>
  ): void;

  const noIssues = pickInput({foo: 3, bar: 3}, {foo: 3}, 'foo');
  const badCall = pickInput({foo: 3, bar: 3}, {bar: 3}, 'foo'); // ERROR 2x
}

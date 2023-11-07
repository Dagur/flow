//@flow

import * as React from 'react';

class Component extends React.Component<{|foo: number, bar: number|}> {
  static defaultProps: {|foo: number|} = {foo: 3};
  render(): number {
    return 3;
  }
}

function TrivialHOC<Props, Instance, Renders>(
  x: React.AbstractComponent<Props, Instance, Renders>,
): React.AbstractComponent<Props, Instance, Renders> {
  return x;
}

const TrivialWrap = TrivialHOC(Component);
TrivialWrap as React.AbstractComponent<
  {|foo?: number, bar: number|},
  Component,
  number,
>; // All ok!

function WrapInDivWithExtraProp<Props, Instance>(
  X: React.AbstractComponent<Props, Instance>,
): React.AbstractComponent<{|...Props, baz: number|}, void> {
  const C = (props: {|...Props, baz: number|}) => (
    <div>
      {props.baz}
      <X {...props} />
    </div>
  );
  C.defaultProps = {...X.defaultProps};
  return C;
}

const WrappedInDivWithExtraProp = WrapInDivWithExtraProp(Component); // Note, we lose instance type here
WrappedInDivWithExtraProp as React.AbstractComponent<
  {|foo?: number, bar: number, baz: number|},
  void,
>;

function AddPropWithDefault<Props, Instance>(
  X: React.AbstractComponent<Props, Instance>,
): React.AbstractComponent<{|...Props, baz?: number|}, void> {
  const C = (props: {|...Props, baz: number|}) => (
    <div>
      {props.baz}
      <X {...props} />
    </div>
  );
  C.defaultProps = {...X.defaultProps, baz: 3};
  return C;
}

const WrappedAddPropWithDefault = AddPropWithDefault(Component);
WrappedAddPropWithDefault as React.AbstractComponent<
  {|foo?: number, bar: number, baz?: number|},
  void,
>;

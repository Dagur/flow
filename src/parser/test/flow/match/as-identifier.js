type match = number;
{
  const match = 1;
}
function match(match: match) {}

// Expression position

const a = match(1);

const b = match(1).f();

const c = match(1)
{
  // block statement
}

const d = match(1) + 2;

const e = match(1)[2];

const f = match(1) ? 2 : 3;

const g = match(1) < 2;

const h = match(1) && 2;

const i = match();

const j = match(...b);

// Statement position

match(1);

match(1).f();

match(1)
{
  // block statement
}

#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

assert_ok "$FLOW" dump-types --strip-root --json --pretty test.js

echo "=== predicates.js ==="
assert_ok "$FLOW" dump-types --strip-root --json --pretty predicates.js

echo "=== type-destructors.js ==="
assert_ok "$FLOW" dump-types --strip-root type-destructors.js | grep '^type-destructors.js:7'

echo "=== type-destructors.js (--evaluate-type-destructors) ==="
assert_ok "$FLOW" dump-types --strip-root --evaluate-type-destructors type-destructors.js | grep '^type-destructors.js:7'

echo "=== elem_call.js ==="
assert_ok "$FLOW" dump-types --strip-root elem_call.js | grep '^elem_call.js:\(4\|7\|10\|13\|17\)'

echo "=== optional_calls.js ==="
assert_ok "$FLOW" dump-types --strip-root optional_calls.js | grep '^optional_calls.js:\(7\|12\|17\|22\|27\|33\)'

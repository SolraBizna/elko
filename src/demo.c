/* This file was automatically generated, and shouldn't be edited manually! */
#line 1 "src/demo.elko"
// -*- c -*-

#include <stdio.h>

union fibonacci_state {
  int _elko_case;
  struct fibonacci_state_frame1 {
    int _elko_case;
#line 6 "src/demo.elko"
    int a;
#line 8 "src/demo.elko"
    int b;
  } frame1;
  struct fibonacci_state_frame2 {
    int _elko_case;
#line 6 "src/demo.elko"
    int a;
#line 8 "src/demo.elko"
    int b;
#line 11 "src/demo.elko"
    int c;
  } frame2;
};
#line 5 "src/demo.elko"
static void fibonacci_init(union fibonacci_state* _elko_state) {
  _elko_state->_elko_case = 0;
}
#line 5 "src/demo.elko"
static int fibonacci(union fibonacci_state* _elko_state) {
  switch(_elko_state->_elko_case)
#line 5 "src/demo.elko"
{
  _elko_top: case 0: {} _elko_state->frame1.a = 1;
#line 7 "src/demo.elko"
{_elko_state->_elko_case = 1; return _elko_state->frame1.a; case 1: {}}
   _elko_state->frame1.b = 1;
#line 9 "src/demo.elko"
{_elko_state->_elko_case = 2; return _elko_state->frame1.b; case 2: {}}
  while(1) {
     _elko_state->frame2.c = _elko_state->frame2.a + _elko_state->frame2.b;
#line 12 "src/demo.elko"
{_elko_state->_elko_case = 3; return _elko_state->frame2.c; case 3: {}}
    _elko_state->frame2.a = _elko_state->frame2.b; _elko_state->frame2.b = _elko_state->frame2.c;
  }
}goto _elko_top;}

union printer_state {
  int _elko_case;
  struct printer_state_frame1 {
    int _elko_case;
#line 17 "src/demo.elko"
    int id;
    int printno;
  } frame1;
  struct printer_state_frame2 {
    int _elko_case;
#line 17 "src/demo.elko"
    int id;
    int printno;
  } frame2;
};
#line 17 "src/demo.elko"
static void printer_init(union printer_state* _elko_state, int id) {
  _elko_state->_elko_case = 0;
  _elko_state->frame1.id = id;
}
#line 17 "src/demo.elko"
static void printer(union printer_state* _elko_state, const char* to_print) {
  switch(_elko_state->_elko_case)
#line 17 "src/demo.elko"
{
  _elko_top: case 0: {} _elko_state->frame1.printno = 0;
#line 19 "src/demo.elko"
while(1) {
    printf("printer %i print #%i: %s\n", _elko_state->frame2.id, ++_elko_state->frame2.printno, to_print);
    {_elko_state->_elko_case = 1; return; case 1: {}}
  }
}goto _elko_top;}

int main() {
  union fibonacci_state fibA, fibB;
  union printer_state print1, print2, print5;
  fibonacci_init(&fibA);
  fibonacci_init(&fibB);
  for(int n = 0; n < 2; ++n) {
    printf("Fibonacci stream A:");
    for(int m = 0; m < 5; ++m) {
      if(m) printf(",");
      printf(" %i", fibonacci(&fibA));
    }
    printf("\nFibonacci stream B:");
    for(int m = 0; m < 5; ++m) {
      if(m) printf(",");
      printf(" %i", fibonacci(&fibB));
    }
    printf("\n");
  }
  printer_init(&print1, 1);
  printer_init(&print2, 2);
  printer_init(&print5, 5);
  printer(&print1, "Lorem ipsum");
  printer(&print2, "Four-score");
  printer(&print5, "Space,");
  printer(&print1, "dolor sit amet");
  printer(&print5, "the final frontier");
  printer(&print2, "and seven years ago");
  return 0;
}

int f, g, y; // global variables

int func(int a, int b) {
  return a << b;
}

void main() {
  f = 2;
  g = 3;
  y = func(f,g);

  //write y to highest address in 4KB memory to check if the value is correct (y is int and vlaue should be 16)
  int *ptr = (int *)(4096 - 4); // highest address in 4KB memory
  *ptr = y;

  while(1);
  return;
}

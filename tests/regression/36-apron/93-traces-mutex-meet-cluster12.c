// SKIP PARAM: --set ana.activated[+] apron --set ana.path_sens[+] threadflag --set ana.apron.privatization mutex-meet-tid-cluster12 --enable ana.sv-comp.functions
extern int __VERIFIER_nondet_int();

#include <pthread.h>
#include <goblint.h>

int g = 0;
int h = 0;
int i = 0;
pthread_mutex_t A = PTHREAD_MUTEX_INITIALIZER;

void *t_fun(void *arg) {
  int x;
  pthread_mutex_lock(&A);
  x = h;
  i = x;
  pthread_mutex_unlock(&A);
  return NULL;
}

int main(void) {
  pthread_t id;
  pthread_create(&id, NULL, t_fun, NULL);

  pthread_mutex_lock(&A);
  g = __VERIFIER_nondet_int();
  h = __VERIFIER_nondet_int();
  i = __VERIFIER_nondet_int();
  pthread_mutex_unlock(&A);

  pthread_mutex_lock(&A);
  int y = __VERIFIER_nondet_int();
  g = y;
  h = y;
  i = y;
  pthread_mutex_unlock(&A);

  pthread_mutex_lock(&A);
  __goblint_check(g == h);
  __goblint_check(h == i);
  pthread_mutex_unlock(&A);
  return 0;
}

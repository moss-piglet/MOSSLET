#!/bin/bash
# Patch vix NIF code for Windows/MSYS2 compatibility

set -e

VIX_DIR="deps/vix/c_src"

if [ ! -d "$VIX_DIR" ]; then
  echo "vix c_src directory not found"
  exit 1
fi

echo "Patching vix for Windows compatibility..."

# Patch pipe.c - Replace POSIX pipe functions with Windows equivalents
cat > "$VIX_DIR/pipe.c" << 'PIPE_EOF'
#include <errno.h>
#include <glib-object.h>
#include <stdio.h>
#include <string.h>
#include <vips/vips.h>

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#include <windows.h>
#define pipe(fds) _pipe(fds, 65536, _O_BINARY)
#define read(fd, buf, size) _read(fd, buf, size)
#define write(fd, buf, size) _write(fd, buf, size)
#define close(fd) _close(fd)
#ifndef EAGAIN
#define EAGAIN WSAEWOULDBLOCK
#endif
#ifndef EWOULDBLOCK
#define EWOULDBLOCK WSAEWOULDBLOCK
#endif
#else
#include <fcntl.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#include "g_object/g_object.h"
#include "pipe.h"
#include "utils.h"

static ErlNifResourceType *FD_RT;

#ifndef _WIN32
static int set_flag(int fd, int flags) {
  return fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | flags);
}
#endif

static void close_pipes(int pipes[2]) {
  for (int i = 0; i < 2; i++) {
    close(pipes[i]);
  }
}

static VixResult fd_to_erl_term(ErlNifEnv *env, int fd) {
  ErlNifPid pid;
  int *fd_r;
  int ret;
  VixResult res;

  fd_r = enif_alloc_resource(FD_RT, sizeof(int));
  *fd_r = fd;

  if (!enif_self(env, &pid)) {
    SET_ERROR_RESULT(env, "failed get self pid", res);
    goto exit;
  }

  ret = enif_monitor_process(env, fd_r, &pid, NULL);

  if (ret < 0) {
    SET_ERROR_RESULT(env, "no down callback is provided", res);
  } else if (ret > 0) {
    SET_ERROR_RESULT(env, "pid is not alive", res);
  } else {
    res = vix_result(enif_make_resource(env, fd_r));
  }

exit:
  enif_release_resource(fd_r);
  return res;
}

ERL_NIF_TERM nif_source_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  ErlNifTime start;
  ERL_NIF_TERM ret;
  ERL_NIF_TERM write_fd_term, source_term;
  VipsSource *source;
  VixResult res;
  int fds[] = {-1, -1};

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (pipe(fds) == -1) {
    ret = make_error(env, "failed to create pipes");
    goto exit;
  }

#ifndef _WIN32
  if (set_flag(fds[0], O_CLOEXEC) < 0 ||
      set_flag(fds[1], O_CLOEXEC | O_NONBLOCK) < 0) {
    ret = make_error(env, "failed to set flags to fd");
    goto close_fd_exit;
  }
#endif

  res = fd_to_erl_term(env, fds[1]);
  if (!res.is_success) {
    ret = make_error_term(env, res.result);
    goto close_fd_exit;
  }

  write_fd_term = res.result;

  source = vips_source_new_from_descriptor(fds[0]);
  if (!source) {
    error("Failed to create image from fd. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to create VipsSource from fd ");
    goto close_fd_exit;
  }

#ifndef _WIN32
  close_fd(&fds[0]);
#endif

  source_term = g_object_to_erl_term(env, (GObject *)source);
  ret = make_ok(env, enif_make_tuple2(env, write_fd_term, source_term));

  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_target_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 0);

  ErlNifTime start;
  VipsTarget *target;
  ERL_NIF_TERM ret, read_fd_term, target_term;
  VixResult res;
  int fds[] = {-1, -1};

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (pipe(fds) == -1) {
    ret = make_error(env, "failed to create pipes");
    goto exit;
  }

#ifndef _WIN32
  if (set_flag(fds[0], O_CLOEXEC | O_NONBLOCK) < 0 ||
      set_flag(fds[1], O_CLOEXEC) < 0) {
    ret = make_error(env, "failed to set flags to fd");
    goto close_fd_exit;
  }
#endif

  res = fd_to_erl_term(env, fds[0]);
  if (!res.is_success) {
    ret = make_error_term(env, res.result);
    goto close_fd_exit;
  }

  read_fd_term = res.result;

  target = vips_target_new_to_descriptor(fds[1]);
  if (!target) {
    error("Failed to create VipsTarget. error: %s", vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to create VipsTarget");
    goto close_fd_exit;
  }

#ifndef _WIN32
  close_fd(&fds[1]);
#endif

  target_term = g_object_to_erl_term(env, (GObject *)target);
  ret = make_ok(env, enif_make_tuple2(env, read_fd_term, target_term));

  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

ERL_NIF_TERM nif_pipe_open(ErlNifEnv *env, int argc,
                           const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ERL_NIF_TERM ret;
  int fds[] = {-1, -1};
  ERL_NIF_TERM read_fd_term, write_fd_term;
  char mode[10] = {0};
  VixResult res;

  if (enif_get_atom(env, argv[0], mode, 9, ERL_NIF_LATIN1) < 1) {
    ret = make_error(env, "failed to get mode");
    goto exit;
  }

  if (pipe(fds) == -1) {
    ret = make_error(env, "failed to create pipes");
    goto exit;
  }

  if (strcmp(mode, "read") == 0) {
#ifndef _WIN32
    if (set_flag(fds[0], O_CLOEXEC | O_NONBLOCK) < 0 ||
        set_flag(fds[1], O_CLOEXEC) < 0) {
      ret = make_error(env, "failed to set flags to fd");
      goto close_fd_exit;
    }
#endif

    res = fd_to_erl_term(env, fds[0]);

    if (!res.is_success) {
      ret = make_error_term(env, res.result);
      goto close_fd_exit;
    }

    read_fd_term = res.result;
    write_fd_term = enif_make_int(env, fds[1]);

  } else {

#ifndef _WIN32
    if (set_flag(fds[0], O_CLOEXEC) < 0 ||
        set_flag(fds[1], O_CLOEXEC | O_NONBLOCK) < 0) {
      ret = make_error(env, "failed to set flags to fd");
      goto close_fd_exit;
    }
#endif

    res = fd_to_erl_term(env, fds[1]);

    if (!res.is_success) {
      ret = make_error_term(env, res.result);
      goto close_fd_exit;
    }

    write_fd_term = res.result;
    read_fd_term = enif_make_int(env, fds[0]);
  }

  ret = make_ok(env, enif_make_tuple2(env, read_fd_term, write_fd_term));
  goto exit;

close_fd_exit:
  close_pipes(fds);

exit:
  return ret;
}

static bool select_write(ErlNifEnv *env, int *fd) {
#ifdef _WIN32
  return true;
#else
  int ret;

  ret = enif_select(env, *fd, ERL_NIF_SELECT_WRITE, fd, NULL, ATOM_UNDEFINED);

  if (ret != 0) {
    error("failed to enif_select write, %d", ret);
    return false;
  }

  return true;
#endif
}

ERL_NIF_TERM nif_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  ErlNifTime start;
  ssize_t size;
  ErlNifBinary bin;
  int write_errno;
  int *fd;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_resource(env, argv[0], FD_RT, (void **)&fd)) {
    ret = make_error(env, "failed to get fd");
    goto exit;
  }

  if (enif_inspect_binary(env, argv[1], &bin) != true) {
    ret = make_error(env, "failed to get binary");
    goto exit;
  }

  if (bin.size == 0) {
    ret = make_error(env, "failed to get binary");
    goto exit;
  }

  size = write(*fd, bin.data, bin.size);
  write_errno = errno;

  if (size >= (ssize_t)bin.size) {
    ret = make_ok(env, enif_make_int(env, size));
  } else if (size >= 0) {
    if (select_write(env, fd)) {
      ret = make_ok(env, enif_make_int(env, size));
    } else {
      ret = make_error(env, "failed to enif_select write");
    }
  } else if (write_errno == EAGAIN || write_errno == EWOULDBLOCK) {
    if (select_write(env, fd)) {
      ret = make_error_term(env, ATOM_EAGAIN);
    } else {
      ret = make_error(env, "failed to enif_select write");
    }
  } else {
    ret = make_error(env, strerror(write_errno));
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

static bool select_read(ErlNifEnv *env, int *fd) {
#ifdef _WIN32
  return true;
#else
  int ret;

  ret = enif_select(env, *fd, ERL_NIF_SELECT_READ, fd, NULL, ATOM_UNDEFINED);

  if (ret != 0) {
    error("failed to enif_select, %d", ret);
    return false;
  }

  return true;
#endif
}

ERL_NIF_TERM nif_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 2);

  ErlNifTime start;
  int max_size;
  int *fd;
  ssize_t result;
  int read_errno;
  ERL_NIF_TERM bin_term = 0;
  ERL_NIF_TERM ret;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!enif_get_resource(env, argv[0], FD_RT, (void **)&fd)) {
    ret = make_error(env, "failed to get fd");
    goto exit;
  }

  if (!enif_get_int(env, argv[1], &max_size)) {
    ret = make_error(env, "failed to get read max_size");
    goto exit;
  }

  if (max_size < 1) {
    ret = make_error(env, "max_size must be >= 0");
    goto exit;
  }

  {
    unsigned char buf[max_size];

    result = read(*fd, buf, max_size);
    read_errno = errno;

    if (result >= 0) {
      unsigned char *temp = enif_make_new_binary(env, result, &bin_term);
      memcpy(temp, buf, result);
      ret = make_ok(env, bin_term);
    } else if (read_errno == EAGAIN || read_errno == EWOULDBLOCK) {
      if (select_read(env, fd)) {
        ret = make_error_term(env, ATOM_EAGAIN);
      } else {
        ret = make_error(env, "failed to enif_select read");
      }
    } else {
      ret = make_error(env, strerror(read_errno));
    }
  }

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}

static bool cancel_select(ErlNifEnv *env, int *fd) {
#ifdef _WIN32
  return true;
#else
  int ret;

  if (*fd != VIX_FD_CLOSED) {
    ret = enif_select(env, *fd, ERL_NIF_SELECT_STOP, fd, NULL, ATOM_UNDEFINED);

    if (ret < 0) {
      error("failed to enif_select stop, %d", ret);
      return false;
    }

    return true;
  }

  return true;
#endif
}

static void fd_rt_dtor(ErlNifEnv *env, void *obj) {
  debug("fd_rt_dtor called");
  int *fd = (int *)obj;
  close_fd(fd);
}

static void fd_rt_stop(ErlNifEnv *env, void *obj, ErlNifEvent event, int is_direct_call) {
#ifdef _WIN32
  debug("fd_rt_stop called");
#else
  debug("fd_rt_stop called %d", (int)(intptr_t)event);
#endif
}

static void fd_rt_down(ErlNifEnv *env, void *obj, ErlNifPid *pid,
                       ErlNifMonitor *monitor) {
  debug("fd_rt_down called");
  int *fd = (int *)obj;
  cancel_select(env, fd);
}

int nif_pipe_init(ErlNifEnv *env) {
  ErlNifResourceTypeInit fd_rt_init;

  fd_rt_init.dtor = fd_rt_dtor;
  fd_rt_init.stop = fd_rt_stop;
  fd_rt_init.down = fd_rt_down;

  FD_RT =
      enif_open_resource_type_x(env, "fd resource", &fd_rt_init,
                                ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  return 0;
}
PIPE_EOF

# Patch utils.c - Replace POSIX close with Windows equivalent
cat > "$VIX_DIR/utils.c" << 'UTILS_EOF'
#include "utils.h"
#include <errno.h>
#include <glib-object.h>
#include <stdbool.h>

#ifdef _WIN32
#include <io.h>
#define close(fd) _close(fd)
#else
#include <unistd.h>
#endif

ErlNifResourceType *VIX_BINARY_RT;

int MAX_G_TYPE_NAME_LENGTH = 1024;

const int VIX_FD_CLOSED = -1;

ERL_NIF_TERM ATOM_OK;
ERL_NIF_TERM ATOM_ERROR;
ERL_NIF_TERM ATOM_NIL;
ERL_NIF_TERM ATOM_TRUE;
ERL_NIF_TERM ATOM_FALSE;
ERL_NIF_TERM ATOM_NULL_VALUE;
ERL_NIF_TERM ATOM_UNDEFINED;
ERL_NIF_TERM ATOM_EAGAIN;

static ERL_NIF_TERM VIX_JANITOR_PROCESS_NAME;

const guint VIX_LOG_LEVEL_NONE = 0;
const guint VIX_LOG_LEVEL_WARNING = 1;
const guint VIX_LOG_LEVEL_ERROR = 2;

guint VIX_LOG_LEVEL = VIX_LOG_LEVEL_NONE;

static void libvips_log_callback(char const *log_domain,
                                 GLogLevelFlags log_level, char const *message,
                                 void *enable) {
  enif_fprintf(stderr, "[libvips]: %s\n", message);
}

static void libvips_log_null_callback(char const *log_domain,
                                      GLogLevelFlags log_level,
                                      char const *message, void *enable) {
}

ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_OK, term);
}

ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, ATOM_ERROR, make_binary(env, reason));
}

ERL_NIF_TERM make_error_term(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, ATOM_ERROR, term);
}

ERL_NIF_TERM raise_exception(ErlNifEnv *env, const char *msg) {
  return enif_raise_exception(env, make_binary(env, msg));
}

ERL_NIF_TERM raise_badarg(ErlNifEnv *env, const char *reason) {
  error("bad argument: %s", reason);
  return enif_make_badarg(env);
}

ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *name) {
  ERL_NIF_TERM ret;
  if (enif_make_existing_atom(env, name, &ret, ERL_NIF_LATIN1)) {
    return ret;
  }
  return enif_make_atom(env, name);
}

ERL_NIF_TERM make_binary(ErlNifEnv *env, const char *str) {
  ERL_NIF_TERM bin;
  ssize_t length;
  unsigned char *temp;

  length = strlen(str);
  temp = enif_make_new_binary(env, length, &bin);
  memcpy(temp, str, length);

  return bin;
}

bool get_binary(ErlNifEnv *env, ERL_NIF_TERM bin_term, char *str,
                size_t dest_size) {
  ErlNifBinary bin;

  if (!enif_inspect_binary(env, bin_term, &bin)) {
    error("failed to get binary string from erl term");
    return false;
  }

  if (bin.size >= dest_size) {
    error("destination size is smaller than required");
    return false;
  }

  memcpy(str, bin.data, bin.size);
  str[bin.size] = '\0';

  return true;
}

VixResult vix_result(ERL_NIF_TERM term) {
  return (VixResult){.is_success = true, .result = term};
}

void send_to_janitor(ErlNifEnv *env, ERL_NIF_TERM label,
                     ERL_NIF_TERM resource_term) {
  ErlNifPid pid;

  if (!enif_whereis_pid(env, VIX_JANITOR_PROCESS_NAME, &pid)) {
    error("Failed to get pid for vix janitor process");
    return;
  }

  if (!enif_send(env, &pid, NULL,
                 enif_make_tuple2(env, label, resource_term))) {
    error("Failed to send unref msg to vix janitor");
    return;
  }

  return;
}

static void vix_binary_dtor(ErlNifEnv *env, void *ptr) {
  VixBinaryResource *vix_bin_r = (VixBinaryResource *)ptr;
  g_free(vix_bin_r->data);
  debug("vix_binary_resource dtor");
}

int utils_init(ErlNifEnv *env, const char *log_level) {
  ATOM_OK = make_atom(env, "ok");
  ATOM_ERROR = make_atom(env, "error");
  ATOM_NIL = make_atom(env, "nil");
  ATOM_TRUE = make_atom(env, "true");
  ATOM_FALSE = make_atom(env, "false");
  ATOM_NULL_VALUE = make_atom(env, "null_value");
  ATOM_UNDEFINED = make_atom(env, "undefined");
  ATOM_EAGAIN = make_atom(env, "eagain");

  VIX_JANITOR_PROCESS_NAME = make_atom(env, "Elixir.Vix.Nif.Janitor");

  VIX_BINARY_RT = enif_open_resource_type(
      env, NULL, "vix_binary_resource", (ErlNifResourceDtor *)vix_binary_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (strcmp(log_level, "warning") == 0) {
    VIX_LOG_LEVEL = VIX_LOG_LEVEL_WARNING;
  } else if (strcmp(log_level, "error") == 0) {
    VIX_LOG_LEVEL = VIX_LOG_LEVEL_ERROR;
  } else {
#ifdef DEBUG
    VIX_LOG_LEVEL = VIX_LOG_LEVEL_ERROR;
#else
    VIX_LOG_LEVEL = VIX_LOG_LEVEL_NONE;
#endif
  }

  if (VIX_LOG_LEVEL == VIX_LOG_LEVEL_WARNING ||
      VIX_LOG_LEVEL == VIX_LOG_LEVEL_ERROR) {
    g_log_set_handler("VIPS", G_LOG_LEVEL_WARNING, libvips_log_callback, NULL);
  } else {
    g_log_set_handler("VIPS", G_LOG_LEVEL_WARNING, libvips_log_null_callback,
                      NULL);
  }

  if (!VIX_BINARY_RT) {
    error("Failed to open vix_binary_resource");
    return 1;
  }

  return 0;
}

int close_fd(int *fd) {
  int ret = 0;

  if (*fd != VIX_FD_CLOSED) {
    ret = close(*fd);

    if (ret != 0) {
      error("failed to close fd: %d, error: %s", *fd, strerror(errno));
    } else {
      *fd = VIX_FD_CLOSED;
    }
  }

  return ret;
}

void notify_consumed_timeslice(ErlNifEnv *env, ErlNifTime start,
                               ErlNifTime stop) {
  ErlNifTime pct;

  pct = (ErlNifTime)((stop - start) / 10);
  if (pct > 100)
    pct = 100;
  else if (pct == 0)
    pct = 1;
  enif_consume_timeslice(env, pct);
}

ERL_NIF_TERM to_binary_term(ErlNifEnv *env, void *data, size_t size) {
  VixBinaryResource *vix_bin_r =
      enif_alloc_resource(VIX_BINARY_RT, sizeof(VixBinaryResource));
  ERL_NIF_TERM bin_term;

  vix_bin_r->data = data;
  vix_bin_r->size = size;

  bin_term = enif_make_resource_binary(env, vix_bin_r, vix_bin_r->data,
                                       vix_bin_r->size);

  enif_release_resource(vix_bin_r);

  return bin_term;
}
UTILS_EOF

echo "vix patched for Windows compatibility"

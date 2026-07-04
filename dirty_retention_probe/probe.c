#include <moonbit.h>

#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <mach/mach.h>
#include <malloc/malloc.h>
#elif defined(__linux__)
#include <sys/resource.h>
#if defined(__GLIBC__)
#include <malloc.h>
#endif
#endif

MOONBIT_FFI_EXPORT
int64_t acyclic_probe_monotonic_us(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return -1;
  }
  return (int64_t)ts.tv_sec * 1000000LL + (int64_t)ts.tv_nsec / 1000LL;
}

MOONBIT_FFI_EXPORT
int64_t acyclic_probe_current_rss_kb(void) {
#if defined(__APPLE__)
  mach_task_basic_info_data_t info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
  kern_return_t status = task_info(
    mach_task_self(),
    MACH_TASK_BASIC_INFO,
    (task_info_t)&info,
    &count
  );
  if (status != KERN_SUCCESS) {
    return -1;
  }
  return (int64_t)info.resident_size / 1024LL;
#elif defined(__linux__)
  long pages = 0;
  FILE *fp = fopen("/proc/self/statm", "r");
  if (fp != NULL) {
    long total_pages = 0;
    if (fscanf(fp, "%ld %ld", &total_pages, &pages) != 2) {
      pages = 0;
    }
    fclose(fp);
  }
  if (pages > 0) {
    return (int64_t)pages * (int64_t)sysconf(_SC_PAGESIZE) / 1024LL;
  }

  struct rusage usage;
  if (getrusage(RUSAGE_SELF, &usage) != 0) {
    return -1;
  }
#if defined(__APPLE__)
  return (int64_t)usage.ru_maxrss / 1024LL;
#else
  return (int64_t)usage.ru_maxrss;
#endif
#else
  return -1;
#endif
}

MOONBIT_FFI_EXPORT
void acyclic_probe_release_unused_memory(void) {
#if defined(__linux__) && defined(__GLIBC__)
  malloc_trim(0);
#elif defined(__APPLE__)
  malloc_zone_pressure_relief(NULL, 0);
#endif
}

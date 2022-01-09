bin_PROGRAMS = hydra-queue-runner

hydra_queue_runner_SOURCES = hydra-queue-runner.cc queue-monitor.cc dispatcher.cc \
 builder.cc build-result.cc build-remote.cc \
 build-result.hh counter.hh state.hh db.hh \
 nar-extractor.cc nar-extractor.hh
hydra_queue_runner_LDADD = $(NIX_LIBS) -lpqxx
hydra_queue_runner_CXXFLAGS = $(NIX_CFLAGS) -Wall -I ../libhydra -Wno-deprecated-declarations

check_PROGRAMS = hydra_queue_runner_tests
TESTS = hydra_queue_runner_tests

hydra_queue_runner_tests_SOURCES = hydra-queue-runner-tests.cc
hydra_queue_runner_tests_CPPFLAGS = $(GTEST_CFLAGS)
hydra_queue_runner_tests_LDFLAGS = $(GTEST_LDFLAGS) -lgtest_main -lgtest



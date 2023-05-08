short_ver = 1.1.9
last_ver = 1.1.8
long_ver = $(shell git describe --long 2>/dev/null || echo $(short_ver)-0-unknown-g`git describe --always`)
generated = aiven_extras.control \
			sql/aiven_extras--$(short_ver).sql \
			sql/aiven_extras--$(last_ver)--$(short_ver).sql

# for downstream packager
RPM_MINOR_VERSION_SUFFIX ?=

# Extension packaging
EXTENSION = aiven_extras
MODULE_big = aiven_extras
OBJS = src/standby_slots.o
PG_CONFIG ?= pg_config
DATA = $(wildcard sql/*--*.sql)
DATA_built = $(generated)
TESTS = $(wildcard test/sql/*.sql)
REGRESS = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=test --outputdir=test/out/
PGXS := $(shell $(PG_CONFIG) --pgxs)
EXTRA_CLEAN = aiven_extras.control aiven-extras-rpm-src.tar

include $(PGXS)

rpm: rpm-96 rpm-10 rpm-11 rpm-12 rpm-13 rpm-14 rpm-15

aiven_extras.control: aiven_extras.control.in
	mkdir -p $(@D)
	sed -e 's,__short_ver__,$(short_ver),g' < $^ > $@

sql/aiven_extras--$(short_ver).sql: sql/aiven_extras.sql
	mkdir -p $(@D)
	cp -fp $^ $@

sql/aiven_extras--$(last_ver)--$(short_ver).sql: sql/aiven_extras.sql
	mkdir -p $(@D)
	cp -fp $^ $@

ifeq ("$(wildcard sql/aiven_extras--*--$(last_ver).sql)","")
	@echo "ERROR: missing upgrade script to last version (sql/aiven_extras--*--$(last_ver).sql)"
	@echo "       -> Please add one (with only --NOOP in it) and commit it"
	@false
endif

rpm-%: $(generated)
	git archive --output=aiven-extras-rpm-src.tar --prefix aiven-extras/ HEAD
	QA_RPATHS=0x0002 rpmbuild -bb aiven-extras.spec \
		--define '_topdir $(PWD)/rpm' \
		--define '_sourcedir $(CURDIR)' \
		--define "_buildrootdir $(CURDIR)/rpm/BUILDROOT" \
		--define "packagenameversion $(subst .,,$(subst rpm-,,$@))" \
		--define "pginstdir /usr/pgsql-$(subst rpm-,,$@)" \
		--define "pgmajorversion $(subst rpm-,,$@)" \
		--define 'major_version $(short_ver)' \
		--define 'minor_version $(subst -,.,$(subst $(short_ver)-,,$(long_ver)))$(RPM_MINOR_VERSION_SUFFIX)'
	$(RM) aiven-extras-rpm-src.tar

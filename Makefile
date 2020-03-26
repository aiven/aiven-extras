short_ver = 1.0.3
long_ver = $(shell git describe --long 2>/dev/null || echo $(short_ver)-0-unknown-g`git describe --always`)
generated = aiven_extras.control aiven_extras--$(short_ver).sql

rpm: rpm-9.6 rpm-10 rpm-11 rpm-12

clean:
	rm -rf rpm aiven-extras-rpm-src.tar $(generated)

aiven_extras.control: aiven_extras.control.in
	sed -e 's,__short_ver__,$(short_ver),g' < $^ > $@

aiven_extras--$(short_ver).sql: sql/aiven_extras.sql
	cp -fp $^ $@

rpm-%: $(generated)
	git archive --output=aiven-extras-rpm-src.tar --prefix=aiven-extras/ HEAD
        # add generated files to the tar, they're not in git repository
	tar -r -f aiven-extras-rpm-src.tar $(generated)
	rpmbuild -bb aiven-extras.spec \
		--define '_topdir $(PWD)/rpm' \
		--define '_sourcedir $(CURDIR)' \
		--define "packagenameversion $(subst .,,$(subst rpm-,,$@))" \
		--define "pgmajorversion $(subst rpm-,,$@)" \
		--define 'major_version $(short_ver)' \
		--define 'minor_version $(subst -,.,$(subst $(short_ver)-,,$(long_ver)))'
	$(RM) aiven-extras-rpm-src.tar

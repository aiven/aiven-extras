%global sname   aiven-extras

Name:           %{sname}_%{pgmajorversion}
Version:        %{major_version}
Release:        %{minor_version}%{?dist}
Url:            http://github.com/aiven/aiven-extras
Summary:        Aiven PostgreSQL extras extension
License:        ASL 2.0
Source0:        aiven-extras-rpm-src.tar
Requires:       postgresql-server, systemd
%undefine _missing_build_ids_terminate_build

%description
Aiven extras is a PostgreSQL extension allowing the use of some PostgreSQL
super-user only functionality as an Aiven administrative user that does not
have full PostgreSQL superuser rights.

%prep
tar xvf %{SOURCE0}
cp aiven_extras.control aiven-extras
cp *.sql aiven-extras/sql
cd aiven-extras

%install
cd aiven-extras;
mkdir -p %{buildroot}/usr/share/doc/aiven-extras-%{pgmajorversion}
mkdir -p %{buildroot}/usr/share/licenses/aiven-extras-%{pgmajorversion}
mkdir -p %{buildroot}/usr/pgsql-%{pgmajorversion}/share/extension
%{__install} -D -m 755 README.md %{buildroot}/usr/share/doc/aiven-extras-%{pgmajorversion}/
%{__install} -D -m 755 LICENSE %{buildroot}/usr/share/licenses/aiven-extras-%{pgmajorversion}/
%{__install} -D -m 755 sql/*.sql %{buildroot}/usr/pgsql-%{pgmajorversion}/share/extension/
%{__install} -D -m 755 aiven_extras.control %{buildroot}/usr/pgsql-%{pgmajorversion}/share/extension/

%files
%defattr(-, root, root)
%dir /usr/pgsql-%{pgmajorversion}/share/extension
/usr/pgsql-%{pgmajorversion}/share/extension/*
%dir /usr/share/doc/aiven-extras-%{pgmajorversion}/
/usr/share/doc/aiven-extras-%{pgmajorversion}/README.md
%dir /usr/share/licenses/aiven-extras-%{pgmajorversion}/
/usr/share/licenses/aiven-extras-%{pgmajorversion}/LICENSE


%changelog
* Tue Aug 7 2018 Hannu Valtonen <hannu.valtonen@aiven.io> - 1.0.0
- Initial release

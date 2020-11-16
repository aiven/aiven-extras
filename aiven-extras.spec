%global sname   aiven-extras
%undefine _missing_build_ids_terminate_build

Name:           %{sname}_%{packagenameversion}
Version:        %{major_version}
Release:        %{minor_version}%{?dist}
Url:            http://github.com/aiven/aiven-extras
Summary:        Aiven PostgreSQL extras extension
License:        ASL 2.0
Source0:        aiven-extras-rpm-src.tar
BuildArch:	noarch

%description
Aiven extras is a PostgreSQL extension allowing the use of some PostgreSQL
super-user only functionality as an Aiven administrative user that does not
have full PostgreSQL superuser rights.


%prep
%setup -n %{sname}


%install
mkdir -p %{buildroot}/usr/share/doc/aiven-extras-%{pgmajorversion}
mkdir -p %{buildroot}/usr/share/licenses/aiven-extras-%{pgmajorversion}
mkdir -p %{buildroot}/usr/pgsql-%{pgmajorversion}/share/extension
%{__install} -D -m 644 README.md %{buildroot}/usr/share/doc/aiven-extras-%{pgmajorversion}/
%{__install} -D -m 644 LICENSE %{buildroot}/usr/share/licenses/aiven-extras-%{pgmajorversion}/
%{__install} -D -m 644 sql/*.sql %{buildroot}/usr/pgsql-%{pgmajorversion}/share/extension/
%{__install} -D -m 644 aiven_extras.control %{buildroot}/usr/pgsql-%{pgmajorversion}/share/extension/

%files
%defattr(-, root, root)
/usr/pgsql-%{pgmajorversion}/share/extension/
/usr/share/doc/aiven-extras-%{pgmajorversion}/
/usr/share/licenses/aiven-extras-%{pgmajorversion}/


%changelog
* Tue Aug 7 2018 Hannu Valtonen <hannu.valtonen@aiven.io> - 1.0.0
- Initial release

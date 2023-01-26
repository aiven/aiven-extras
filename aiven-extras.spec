%global sname   aiven-extras
%global extname aiven_extras
%undefine _missing_build_ids_terminate_build

Name:           %{sname}_%{packagenameversion}
Version:        %{major_version}
Release:        %{minor_version}%{?dist}
Url:            http://github.com/aiven/aiven-extras
Summary:        Aiven PostgreSQL extras extension
License:        ASL 2.0
Source0:        aiven-extras-rpm-src.tar
BuildRequires:	postgresql%{pgmajorversion}-devel pgdg-srpm-macros
Requires:	postgresql%{pgmajorversion}-server

%description
Aiven extras is a PostgreSQL extension allowing the use of some PostgreSQL
super-user only functionality as an Aiven administrative user that does not
have full PostgreSQL superuser rights.


%prep
%setup -n %{sname}

%install
%{__rm} -rf %{buildroot}

USE_PGXS=1 PATH=%{pginstdir}/bin/:$PATH %{__make} %{?_smp_mflags} install DESTDIR=%{buildroot}
mkdir -p %{buildroot}/usr/share/doc/aiven-extras-%{pgmajorversion}
mkdir -p %{buildroot}/usr/share/licenses/aiven-extras-%{pgmajorversion}
%{__install} -D -m 644 README.md %{buildroot}/usr/share/doc/aiven-extras-%{pgmajorversion}/
%{__install} -D -m 644 LICENSE %{buildroot}/usr/share/licenses/aiven-extras-%{pgmajorversion}/

%clean
%{__rm} -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-, root, root)
/usr/share/doc/aiven-extras-%{pgmajorversion}/
/usr/share/licenses/aiven-extras-%{pgmajorversion}/

%defattr(644,root,root,755)
%{pginstdir}/lib/%{extname}.so
%{pginstdir}/share/extension/%{extname}--*.sql
%{pginstdir}/share/extension/%{extname}.control
%if %{pgmajorversion} >= 11 && %{pgmajorversion} < 90
 %if 0%{?rhel} && 0%{?rhel} <= 6
 %else
 %{pginstdir}/lib/bitcode/%{extname}*.bc
 %{pginstdir}/lib/bitcode/%{extname}/src/*.bc
 %endif
%endif

%changelog
* Tue Aug 7 2018 Hannu Valtonen <hannu.valtonen@aiven.io> - 1.0.0
- Initial release

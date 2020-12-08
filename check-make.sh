total=`ls rpm-specs/ | wc -w`

uses_make=""
might_use_make=""

for f in rpm-specs/*; do

    # Skip some known false positives:
    case $f in
        rpm-specs/gap-pkg-circle.spec)
            continue
            ;;
        *)
            ;;
    esac

    # Check if we for sure use make
    if grep -l -q -e '\(^\|[^%]\)%make_build' -e '\(^\|[^%]\)%make_install' -e '\(^\|[^%]\)%__make' -e '\(^\|[^%]\)%{make_build}' -e '\(^\|[^%]\)%{make_install}' -e '\(^\|[^%]\)%{__make}' -e '^make ' -e '^DESTDIR.\+make' -e '^OPT.\+make' $f; then
        uses_make="$uses_make $f"
        continue
    fi

    # Check if something might use make
    if grep -q -e make $f; then
        might_use_make="$might_use_make $f"
        continue
    fi
done

# Check if the spec file has BuildRequires: make
for f in `grep -l -e '^BuildRequires:.\+\?[[:space:],]make' rpm-specs/*`; do
	basename $f | sed 's/\.spec//'
done | sort > spec_br_make.txt

num_uses_make=`echo $uses_make | wc -w`
num_might_use_make=`echo $might_use_make | wc -w`

echo "Total: $total"
echo "Uses Make: $num_uses_make"
echo "Might Use Make: $num_might_use_make"

for p in $uses_make; do
    basename $p | sed 's/\.spec//'
done | sort > uses_make.txt

for p in $might_use_make; do
    basename $p | sed 's/\.spec//'
done | sort > might_use_make.txt

dnf --releasever=rawhide repoquery --qf %{name} --disablerepo=* --enablerepo=fedora-source --arch=src --whatrequires make | cat spec_br_make.txt - | sort | uniq > buildrequires_make.txt 2>/dev/null

echo "BuildRequires Make: `wc -l buildrequires_make.txt | grep -o '^[0-9]\+'`"

# The archive directory has the builds results from mass rebuild with make
# removed from buildroot.
if [ -d archive ]; then
    if [ ! -e fail_nomake.txt ]; then
        for f in `find archive/ -iname '*FAIL*'`; do
            basename $f | cut -c 6- | sed 's/\.log$//g' | python nvr-to-name.py
        done | sort > fail_nomake.txt
    fi
fi

if [ -e fail_nomake.txt ]; then

    echo "Fail with no make `wc -l fail_nomake.txt | grep -o '^[0-9]\+'`"

    cat uses_make.txt fail_nomake.txt | sort | uniq | grep -v -x -F -f buildrequires_make.txt  > needs_br_make.txt

    echo "Needs BuildRequires Make: `wc -l needs_br_make.txt | grep -o '^[0-9]\+'`"
fi

set -e

workdir='rpms'
dryrun=0
manual=1

input_file=$1

pushd $workdir

pkg_list=$(cat)

#while IFS= read -r pkg; do
#for pkg in `cat $input_file`; do
for pkg in $pkg_list; do
    echo "===== $pkg ====="

    if [ "$pkg" = "compton" ]; then
        continue
    fi

    if [ ! -d $pkg ]; then
        fedpkg clone $pkg > /dev/null
    fi

    pushd $pkg > /dev/null
    # Make sure the tree is clean
    git reset -q --hard

    git fetch -q
    git rebase -q origin master


    spec="$pkg.spec"
    if [ ! -f $spec ]; then
        echo "NO CHANGE: Spec file not found"
	if [ "$manual" -ne 1 ]; then
            popd > /dev/null
            continue
	fi
    fi

    if grep -q -e '^BuildRequires:.\+\?[[:space:],]make' $spec; then
        echo "NO CHANGE: Already BuildRequires: make"
        popd > /dev/null
        continue
    fi

    tac $spec | sed '0,/^Build[rR]equires:.\+/{s/\(^Build[rR]equires:.\+\)/BuildRequires: make\n\1/}' | tac > $spec.tmp
    mv $spec.tmp $spec

    if git diff --exit-code; then
        echo "NO CHANGE: Failed to update spec"
	if [ "$manual" -ne 1 ]; then
            popd > /dev/null
            continue
	fi
    fi

    if !  git diff --stat | grep -q '1 file changed, 1 insertion'; then
        echo "NO CHANGE: Update is not correct"
	if [ "$manual" -ne 1 ]; then
            popd > /dev/null
            continue
	fi
    fi

    if git diff | grep -q '%endif'; then
	echo "NO CHANGE: Detected %endif"
	if [ "$manual" -ne 1 ]; then
            popd > /dev/null
            continue
	else
            perl -i -pe 'BEGIN{undef $/;} s/BuildRequires: make\n%endif/%endif\nBuildRequires: make/smg' $spec
	    git diff
	fi
    fi

    git commit -a -F- <<EOF
Add BuildRequires: make

https://fedoraproject.org/wiki/Changes/Remove_make_from_BuildRoot
EOF
    if [ "$dryrun" -eq 1 ]; then
        git --no-pager log -p HEAD~1..HEAD
        git reset -q --hard HEAD~1
    else
        if [ "$manual" -eq 1 ]; then
            git --no-pager log HEAD~1..HEAD
            read -p "Do you want to push this change [y/n]" should_push < /dev/tty
            if [ "$should_push" != "y" ]; then
                git reset -q --hard HEAD~1
                echo "NO CHANGE: Manually rejected"
                popd > /dev/null
                continue
            fi
        fi
        git push origin master:master
    fi
    popd > /dev/null
done

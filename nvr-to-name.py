from dnf.subject import Subject
import hawkey
import sys

def get_pkg_name(srpm):
    subject = Subject(srpm)
    nevra = subject.get_nevra_possibilities(forms=hawkey.FORM_NEVRA)
    if not nevra:
        name = subject.get_nevra_possibilities(forms=hawkey.FORM_NAME)
        if not name:
            return ""
        return name[0].name
    return nevra[0].name


print(get_pkg_name(sys.stdin.readlines()[0]))

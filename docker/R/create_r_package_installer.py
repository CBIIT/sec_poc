from rpy2.robjects.packages import importr
import rpy2.robjects as ro
from functools import cache
from os.path import dirname, join as pjoin, basename
import re
import rpy2.robjects as robjects
import rpy2.robjects.packages as rpackages
from rpy2.robjects.vectors import StrVector

# Set the default CRAN mirror option to the CDN cloud mirror
robjects.r("options(repos=c(CRAN='https://cloud.r-project.org'))")
PATTERN = re.compile(r"^pak::pkg_install[(]\"cran/(?P<package>.*?)@(?P<version>.*?)\"\s*[,)].*$")


def main():
    utils = importr('utils')

    def extract_versions(package_data):
        """
        Helper function to extract package names and versions from R package data.
        """
        return dict(zip(
            package_data.rx(True, 'Package'),  # get Package column
            package_data.rx(True, 'Version')  # get Version column
        ))
    available_packages = extract_versions(utils.available_packages())
    lst = open(pjoin(dirname(__file__), 'files', 'install_deps.pak.R'), 'rt').read().split('\n')
    out = ['options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))))']
    for line in lst:
        if line.startswith('#'):
            out.append(line)
            continue
        if m:=PATTERN.match(line):
            package_name = m['package']
            oldv = m['version']
            newv = available_packages.get(package_name)
            if oldv != newv:
                print(package_name, oldv, newv)
            # pak::pkg_install("cran/shiny@1.8.1", ask = FALSE)
            out.append(f'pak::pkg_install("cran/{package_name}@{newv}", ask = FALSE)')
    open(pjoin(dirname(__file__), 'files', 'quick-install-r-packages.R'), 'wt').write('\n'.join(out))
    print(f'WROTE files/install_deps.pak.R')

if __name__ == "__main__":
    main()

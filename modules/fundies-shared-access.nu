#!/usr/bin/env nu
# One-time, idempotent repair of the existing /var/lib/fundies tree so yt and
# fundies can both use it: group ownership, setgid on directories, and a default
# ACL so files either account creates stay writable by the other.
#
# The ACL names the operator's account as well as the group, because a
# supplementary group is fixed when a session starts: this way the repair works
# immediately, with nothing restarted and no one logged out.
#
# It rewrites metadata only - no file is copied, decoded, rewritten or deleted -
# and a second run finds nothing left to do. Run it once, as root, after switching:
#
#   sudo nu modules/fundies-shared-access.nu --check
#   sudo nu modules/fundies-shared-access.nu
#
# modules/fundies-shared.nix carries the same policy for the directories that
# already exist and for everything created after this run.

def main [
    --check # report what the repair would touch, and change nothing
    --data-dir: path = "/var/lib/fundies"
    --group: string = "fundies"
    --operator: string = "yt" # the account that shares the tree by uid, not by group
] {
    require-root
    if $check {
        print-plan (plan $data_dir $group)
        return
    }
    repair-dirs $data_dir $group $operator
    repair-files $data_dir $group $operator
    print-plan (plan $data_dir $group)
}

# Only root can hand a tree to another group, and only root may name another
# account in an ACL entry.
def require-root [] {
    let uid = (^id -u | str trim)
    if $uid != "0" {
        error make { msg: "run this as root: sudo nu modules/fundies-shared-access.nu" }
    }
}

# `-xdev` keeps the walk inside the data's own filesystem, and the predicates pick
# only what is not already shared, so the counts are the work that is left.
def plan [data: path, group: string] {
    {
        directories: (
            ^find $data -xdev -type d "(" "!" -group $group -o "!" -perm -2070 ")" -printf "."
            | str length
        )
        files: (
            ^find $data -xdev -type f "(" "!" -group $group -o "!" -perm -0060 ")" -printf "."
            | str length
        )
    }
}

def print-plan [plan: record] {
    print $"directories needing group, setgid or group write: ($plan.directories)"
    print $"files needing group or group write: ($plan.files)"
}

# `g+rwXs` adds group write and setgid; `o-w` only removes world write. The default
# ACL is the part chmod cannot express: it keeps new files writable by both accounts
# whatever umask the writer had. Both are idempotent.
def repair-dirs [data: path, group: string, operator: string] {
    mine $data "d" "-2070" "g+rwXs,o-w" $group
    ^find $data -xdev -type d -exec setfacl -m (acl-entries $operator) "{}" "+"
}

def repair-files [data: path, group: string, operator: string] {
    mine $data "f" "-0060" "g+rw,o-w" $group
    ^find $data -xdev -type f -exec setfacl -m (file-entries $operator) "{}" "+"
}

# Files need the operator as a *named entry*, not only group write: the jobs run as
# an account whose session predates the group membership, so group bits alone give
# it `Permission denied` on the first lock file it opens. Read and write only, and
# setfacl recalculates the mask, so the group class keeps its bits and other stays
# closed; a 0600 file stays closed to the group.
def file-entries [operator: string]: nothing -> string {
    $"u:($operator):rw"
}

# The mask is explicit: acl_from_text wants one as soon as there is a named entry.
def acl-entries [operator: string]: nothing -> string {
    $"u::rwx,u:($operator):rwx,g::rwx,m::rwx,o::---,d:u::rwx,d:u:($operator):rwx,d:g::rwx,d:m::rwx,d:o::---"
}

# `-exec ... +` batches the work, so even a 12-million-file tree is a handful of
# processes rather than one per file.
def mine [data: path, kind: string, perm: string, mode: string, group: string] {
    ^find $data -xdev -type $kind "(" "!" -group $group -o "!" -perm $perm ")" -exec chgrp $group "{}" "+" -exec chmod $mode "{}" "+"
}

############ GLUM BEGIN
# GLUM (git latest upstream/master; or, works like a merge, but looks like a rebase)
# Easy commands to manipulate your fork and make PRs
# Useful for projects where "rebasing" is required,
# but doing things the "rebase way" might not work for you.
# can be used for any branch, personal remote, and shared remote by changing these vars:
export GLUM_MASTER_BRANCH='master'  # for sme this may be 'dev' or 'development'
export GLUM_ORIGIN_REMOTE='origin'
export GLUM_UPSTREAM_REMOTE='upstream' # leave as upstream if only using non-forked flows to prevent accidental forced pushes
export GLUM_HEAD='HEAD'

### AMEND
# Convienence to change commit message alone,
# but usually easier just to do `glum "AMENDED MESSAGE"`,
# so probably unnecessary, other than maybe being marginally faster.
glum_amend() {
  if [[ $1 ]] ; then
    git commit --amend -m "$1"
  else
    (>&2 echo "No message name.") && false
  fi
}

### FLATTEN AND MOVE CURRENT CHANGES ON ORIGIN/MASTER TO A BRANCH
# For if commits have been made directly to master,
# but need them moved to another branch to do non-overlapping task on a "clean" origin/master
glum_branch() {
  if [[ $1 ]] ; then
    git checkout -b "$1" \
    && git push --set-upstream "$GLUM_ORIGIN_REMOTE" "$1" \
    && git checkout "$GLUM_MASTER_BRANCH" \
    && git reset --hard `glum_common_parent` \
    && git clean -dfx \
    && git push -f
  else
    (>&2 echo "No branch name specified.") && false
  fi
}

### FIND COMMON PARENT
# This will find the common/shared parent between your fork and upstream/master,
# since upstream master may now be ahead.
# Used in several other functions; the core of GLUM.
glum_common_parent() {
  git merge-base "$GLUM_UPSTREAM_REMOTE"/"$GLUM_MASTER_BRANCH" "$GLUM_HEAD"
}

# Simpler alternative to using 'git rebase -i HEAD~X' to crush/squash/flatten commits into a single commit.
# Will have the total diff between HEAD and the common parent of HEAD and upstream/master (since it was last pulled).
glum_flat() {
  git fetch "$GLUM_UPSTREAM_REMOTE" && git reset --soft `glum_common_parent`
}

# Easy reminder how to find "lost"/hidden commits
glum_help() {
  echo "git reflog"
  echo "Find missing commit; will be one of the 'HEAD@{X}'"
  echo "git reset --hard HEAD@{X}"
}

# Full reset/clean of repo to remove any uncommited changes, new untracked files, and ignored files.
glum_reset() {
  #TODO git clean from parent?
  git clean -dfx && git reset --hard
}

### STASH
# Convienence to stash either with name or without; defaulting to date/time.
glum_stash() {
  if [[ $1 ]] ; then
    git stash push -m "$1"
  else
    git stash push -m `date '+%Y-%m-%dT%H:%M'`
  fi
}

### GLUM STEP 1
# flattens all commits since diverging from master into a single new commit,
# with the message passed from the commandline or the message from the last commit on origin/master
glum_step1() {
  if [[ $1 ]] ; then
    glum_flat && git commit -m "$1" || true
  else
    LAST_COMMIT_MESSAGE="$(git log "$GLUM_HEAD" -1 --pretty=%B)"
    glum_flat && git commit -m "$LAST_COMMIT_MESSAGE" || true
  fi
}

### GLUM STEP 2
# This will merge in the latest from upstream/master and stop here until you have resolved them and commit, the run glum again
glum_step2() {
  git merge -m "$LAST_COMMIT_MESSAGE" "$GLUM_UPSTREAM_REMOTE"/"$GLUM_MASTER_BRANCH"
}

### GLUM STEP 3
# Once here, all conflicts have already been resolved and commited,
# and since those commits have been included and HEAD is just one commit ahead,
# rebase will just automatically use the result you've already specified.
# (When rebasing 'theirs' means 'ours', so therefore 'our' version is the one prioritized.)
# If might get stuck if ours is the same as upstream, in which case it's only the one and we can skip.
glum_step3() {
  git rebase -X theirs "$GLUM_UPSTREAM_REMOTE"/"$GLUM_MASTER_BRANCH" # Detect if failed
  git rebase --skip 2> /dev/null && echo "Current commit same as upstream; skipping."
  if [[ $GLUM_ORIGIN_REMOTE != $GLUM_UPSTREAM_REMOTE ]] ; then
    git push -f
  else
    echo "Origin and Upstream are the same; won't force push."
  fi
}

# if it fails because it doesn't have anything to do
glum_abort() {
  git checkout "$GLUM_MASTER_BRANCH" #
  git rebase --abort
  if [[ $GLUM_ORIGIN_REMOTE != $GLUM_UPSTREAM_REMOTE ]] ; then
    git push -f
  else
    echo "Origin and Upstream are the same; won't force push."
  fi
}

### GLUM
# This single command can be used safely to do a variety of tasks
# 1. If only one commit on head, will just recommit with a new message
# 2. If multiple commits will crush into one commit with either the last message or the one passed from the command line
# 3. If no commits, then just does a straight merge/rebase from upstream/master (acts like a merge; looks like a rebase)
# Make sure local HEAD is commited/pushed to origin/master
glum() {
  glum_step1 "$1" && glum_step2 && glum_step3
}
############ GLUM END

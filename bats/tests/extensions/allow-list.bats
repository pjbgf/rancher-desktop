load '../helpers/load'

local_setup() {
    CONTAINERD_NAMESPACE=rancher-desktop-extensions
    TESTDATA_DIR_HOST=$(host_path "${PATH_BATS_ROOT}/tests/extensions/testdata/")
}

write_allow_list() { # list
    local list=${1:-}
    local allowed=true

    if [ -z "$list" ]; then
        allowed=false
    fi

    # Note that the list preference is not writable using `rdctl set`, and we
    # need to do a direct API call instead.

    # TODO TODO TODO
    # Once https://github.com/rancher-sandbox/rancher-desktop/issues/4939 has been
    # implemented, the `version` field  should be made a constant. Putting in the
    # current version here doesn't guarantee that the structure conforms to the latest
    # schema; we should rely on migrations instead.
    # TODO TODO TODO
    rdctl api /v1/settings --input - <<<'{
        "version": '"$(get_setting .version)"',
        "application": {
            "extensions": {
                "allowed": {
                    "enabled": '"${allowed}"',
                    "list": '"${list:-[]}"'
                }
            }
        }
    }'
}

check_extension_installed() { # refute, name
    run rdctl extension ls
    assert_success
    "${1:-assert}_output" --partial "${2:-rd/extension/basic}"
}

@test 'factory reset' {
    factory_reset
}

@test 'start container engine' {
    RD_ENV_EXTENSIONS=1 start_container_engine
}

@test 'switch to cgroup v2' {
    # TODO TODO TODO This is a workaround because #5363 hasn't been fixed yet
    if is_windows; then
        skip "Skipped because switching cgroup layout is not needed on Windows"
    fi
    wait_for_shell
    rdsudo sed -E -i 's/#(rc_cgroup_mode).*/\1="unified"/' /etc/rc.conf
    rdsudo sync
    rdctl shutdown
    RD_ENV_EXTENSIONS=1 start_container_engine
}

@test 'wait for container engine' {
    wait_for_container_engine
}

@test 'build extension testing image' {
    ctrctl build \
        --tag "rd/extension/basic" \
        --build-arg "variant=basic" \
        "$TESTDATA_DIR_HOST"

    run ctrctl image list --format '{{ .Repository }}'
    assert_success
    assert_line "rd/extension/basic"
}

@test 'when no extension allow list is set up, all extensions can install' {
    write_allow_list ''
    rdctl extension install rd/extension/basic
    check_extension_installed
    rdctl extension uninstall rd/extension/basic
}

@test 'empty allow list disables extension installs' {
    write_allow_list '[]'
    run rdctl extension install rd/extension/basic
    assert_failure
    check_extension_installed refute
}

@test 'when an extension is explicitly allowed, it can be installed' {
    write_allow_list '["irrelevant/image","rd/extension/basic:latest"]'
    rdctl extension install rd/extension/basic:latest
    check_extension_installed
    rdctl extension uninstall rd/extension/basic
    check_extension_installed refute
}

@test 'when an extension is not in the allowed list, it cannot be installed' {
    write_allow_list '["rd/extension/other","registry.test/image"]'
    run rdctl extension install rd/extension/basic
    assert_failure
    check_extension_installed refute
}

@test 'when no tags given, any tag is allowed' {
    write_allow_list '["rd/extension/basic"]'
    ctrctl tag rd/extension/basic rd/extension/basic:0.0.3
    rdctl extension install rd/extension/basic:0.0.3
    check_extension_installed
    rdctl extension uninstall rd/extension/basic
    check_extension_installed refute
}

@test 'when tags are given, only the specified tag is allowed' {
    sleep 20
    write_allow_list '["rd/extension/basic:0.0.2"]'
    ctrctl tag rd/extension/basic rd/extension/basic:0.0.3
    run rdctl extension install rd/extension/basic:0.0.3
    assert_failure
    check_extension_installed refute
}

@test 'extensions can be allowed by organization' {
    write_allow_list '["rd/extension/"]'
    rdctl extension install rd/extension/basic
    check_extension_installed
    rdctl extension uninstall rd/extension/basic
    check_extension_installed refute
}

@test 'extensions can be allowed by repository host' {
    write_allow_list '["registry.test/"]'
    ctrctl tag rd/extension/basic registry.test/basic:0.0.3
    rdctl extension install registry.test/basic:0.0.3
    check_extension_installed '' registry.test/basic
    rdctl extension uninstall registry.test/basic
    check_extension_installed refute registry.test/basic
}

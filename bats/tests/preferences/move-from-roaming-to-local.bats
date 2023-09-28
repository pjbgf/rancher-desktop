load '../helpers/load'

local_setup() {
    if ! is_windows; then
        skip 'appdata => localData migration is windows-only'
    fi
}

@test 'factory reset' {
    factory_reset
}

@test 'start app, create a setting, and move settings to roaming' {
    start_container_engine
    wait_for_container_engine
    rdctl api -X PUT --body '{ "version": '"$(get_setting .version)"', "WSL": {"integrations": { "beaker" : true }}}'
    rdctl shutdown
    roamingHome="$(win32env APPDATA)/rancher-desktop"
    mkdir -p "$roamingHome"
    mv "$PATH_CONFIG/settings.json" "$roamingHome/settings.json"
}

@test 'restart app, verify settings has been migrated' {
    launch_the_application
    wait_for_container_engine
    run rdctl api /settings
    assert_success
    run jq_output .WSL.integrations.beaker
    assert_success
    assert_output true
    # Verify the file exists in both Local/ and Roaming/
    # Migration doesn't delete it from Roaming/ in case the user decides to roll back to an earlier version
    # factory-reset deletes all of Roaming/rancher-desktop
    test -f "$PATH_CONFIG/settings.json"
    test -f "$(win32env APPDATA)/rancher-desktop/settings.json"
}

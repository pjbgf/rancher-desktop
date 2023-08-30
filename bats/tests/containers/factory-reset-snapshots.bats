load '../helpers/load'

local_setup() {
    skip_on_windows
    if is_macos; then
        APP_HOME="$PATH_APP_HOME"
    else
        APP_HOME="$PATH_DATA"
    fi
    SNAPSHOTS_DIR="$APP_HOME/snapshots"
    FAKE_OUT=fake.out
}

verify_factory_reset_clears_data_dir() {
    rdctl shutdown
    rdctl factory-reset
    assert_not_exists "$SNAPSHOTS_DIR"
    assert_not_exists "$APP_HOME"
}

@test 'factory reset' {
    factory_reset
}

@test 'Start up Rancher Desktop with a snapshots subdirectory' {
    start_container_engine
    wait_for_container_engine
    mkdir -p "$SNAPSHOTS_DIR"
    touch "$SNAPSHOTS_DIR/$FAKE_OUT"
}

@test "Verify the snapshot dir isn't deleted on factory-reset" {
    rdctl factory-reset
    assert_exists "$SNAPSHOTS_DIR"
    assert_exists "$SNAPSHOTS_DIR/$FAKE_OUT"
    assert_not_exists "$APP_HOME/lima"
}

@test 'Verify factory-reset deletes an empty snapshots directory' {
    rm -f "$SNAPSHOTS_DIR"/*
    rdctl factory-reset
    assert_not_exists "$APP_HOME"
}

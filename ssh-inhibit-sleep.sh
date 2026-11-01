#!/usr/bin/env bash
# Requires sshd "UsePAM yes" in sshd; without it SSH logins are not logind sessions, so this will fail to detect them.

# Create a transient mutex service so we know the state of the service
mutex_unit="ssh-inhibit-sleep-lock.service"

remote_ssh_session_exists() {
    local id info
    for id in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
        info="$(loginctl show-session "${id}" -p Remote -p Service -p State 2>/dev/null)" || continue
        # "closing" sessions have logged out but left processes running.
        [[ "${info}" == *Remote=yes* && "${info}" == *Service=sshd* && "${info}" != *State=closing* ]] && return 0
    done
    return 1
}

if remote_ssh_session_exists; then
    if ! systemctl is-active --quiet "${mutex_unit}"; then
        systemctl reset-failed "${mutex_unit}" 2>/dev/null  # systemd-run would barf on a failed ${mutex_unit}, so reset
        systemd-run --unit="${mutex_unit}" --no-block \
            systemd-inhibit --what=sleep --why="Active SSH session" sleep infinity
    fi
elif systemctl is-active --quiet "${mutex_unit}"; then
    systemctl stop "${mutex_unit}"
fi

exit 0

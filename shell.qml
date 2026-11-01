import "modules/bar"
import "modules/notifs"
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    NotifToasts {}
    NotifCenter {}
}

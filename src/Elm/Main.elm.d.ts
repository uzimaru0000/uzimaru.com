export namespace Elm {
    namespace Main {
        interface App {
            ports: any
        }

        interface Args {
            node: HTMLElement,
            flags: Flags
        }

        interface Flags {}

        function init(args: Args): App
    }
}

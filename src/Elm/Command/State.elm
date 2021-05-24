module Command.State exposing (..)

type ProcState a
    = Running a
    | Error a String
    | Exit a
    

map : (a -> b) -> ProcState a -> ProcState b
map f a =
    case a of
        Running s -> Running (f s)
        Error s msg -> Error (f s) msg
        Exit s -> Exit (f s)

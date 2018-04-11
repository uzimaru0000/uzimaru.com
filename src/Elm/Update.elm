module Update exposing (..)

import Model exposing (..)
import Content exposing (..)
import Http
import Material


-- update


getPost : String -> (Int, String) -> Cmd Msg
getPost host (id, url) =
    Http.send (GetPost host id) <|
        (Http.get (String.join "/" [ host, url ]) postDecoder)


getContent : Int -> String -> Cmd Msg
getContent id url =
    Http.send (GetContent id) <|
        Http.getString url


postUrl : List String
postUrl =
    [ "post/works.json"
    , "post/about.json"
    , "post/links.json"
    ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetHost host ->
            model ! [ postUrl |> List.indexedMap (,) |> List.map (getPost host) |> Cmd.batch ]

        GetPost host id (Ok post) ->
            let
                cardInfo =
                    { id = id
                    , post = post
                    , content = ""
                    , isActive = False
                    }

                contents =
                    cardInfo :: model.contents
                        |> List.sortBy .id
            in
                { model | contents = contents } ! [ getContent id (host ++ "/" ++ post.contentUrl) ]

        GetContent id (Ok content) ->
            let
                newContents =
                    model.contents
                        |> List.map
                            (\x ->
                                if x.id == id then
                                    { x | content = content }
                                else
                                    x
                            )
            in
                { model | contents = newContents } ! []

        GetPost _ _ (Err err) ->
            let
                a = Debug.log "error" err
            in
                model ! []

        MouseEnter id ->
            { model | contents = List.map (changeCardState id True) model.contents } ! []

        MouseLeave id ->
            { model | contents = List.map (changeCardState id False) model.contents } ! []

        CardFocus info ->
            { model | focusCard = info, firstModal = True } ! []

        Mdl msg_ ->
            Material.update Mdl msg_ model

        _ ->
            model ! []


changeCardState : Int -> Bool -> CardInfo -> CardInfo
changeCardState id state info =
    if info.id == id then
        { info | isActive = state }
    else
        info

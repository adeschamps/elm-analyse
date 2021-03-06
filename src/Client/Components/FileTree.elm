module Client.Components.FileTree exposing (Model, Msg, init, onNewState, subscriptions, update, view)

import Analyser.Messages.Types exposing (GroupedMessages, Message, groupByType)
import Client.Components.MessageList as MessageList
import Client.State
import Dict
import Html exposing (Html)
import Html.Attributes
import Html.Events exposing (onClick)
import Http
import Json.Decode as JD
import Navigation exposing (Location)


type alias Model =
    { hideGoodFiles : Bool
    , tree : Maybe (List String)
    , fileIndex : Maybe FileIndex
    , selectedFile : Maybe String
    , messageList : MessageList.Model
    }


type alias FileIndex =
    List ( String, List Message )


type Msg
    = OnFileTree (Result Http.Error (List String))
    | MessageListMsg MessageList.Msg
    | OnSelectFile String
    | ToggleHideGoodFiles


init : ( Model, Cmd Msg )
init =
    ( { tree = Nothing
      , hideGoodFiles = True
      , fileIndex = Nothing
      , selectedFile = Nothing
      , messageList = MessageList.init Dict.empty
      }
    , Cmd.batch
        [ Http.get "/tree" (JD.list JD.string) |> Http.send OnFileTree
        ]
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    MessageList.subscriptions model.messageList |> Sub.map MessageListMsg


updateFileIndex : Maybe (List Message) -> Model -> Model
updateFileIndex maybeMessages model =
    let
        messagesForFile file messages =
            messages
                |> List.filter
                    (\ms -> ms.file.path == file)

        buildTree messages tree =
            List.map (\file -> ( file, messagesForFile file messages )) tree
    in
    { model | fileIndex = Maybe.map2 buildTree maybeMessages model.tree }


updateMessageList : Model -> Model
updateMessageList m =
    { m | messageList = MessageList.withMessages (messagesForSelectedFile m) m.messageList }


onNewState : Client.State.State -> Model -> Model
onNewState s model =
    let
        messages =
            s
                |> Client.State.toMaybe
                |> Maybe.map .messages
    in
    updateFileIndex messages model
        |> updateMessageList


update : Client.State.State -> Location -> Msg -> Model -> ( Model, Cmd Msg )
update state location msg model =
    case msg of
        OnFileTree x ->
            case x of
                Ok value ->
                    ( updateFileIndex
                        (Client.State.toMaybe state |> Maybe.map .messages)
                        { model | tree = Just value }
                    , Cmd.none
                    )

                Err _ ->
                    ( model
                    , Cmd.none
                    )

        OnSelectFile x ->
            ( { model | selectedFile = Just x } |> updateMessageList, Cmd.none )

        ToggleHideGoodFiles ->
            ( { model | hideGoodFiles = not model.hideGoodFiles }
            , Cmd.none
            )

        MessageListMsg subMsg ->
            MessageList.update location subMsg model.messageList
                |> Tuple.mapFirst (\x -> { model | messageList = x })
                |> Tuple.mapSecond (Cmd.map MessageListMsg)


messagesForSelectedFile : Model -> GroupedMessages
messagesForSelectedFile m =
    case m.fileIndex of
        Just fileIndex ->
            fileIndex
                |> List.filter (Tuple.first >> Just >> (==) m.selectedFile)
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault []
                |> groupByType

        _ ->
            Dict.empty


view : Model -> Html Msg
view m =
    let
        allowFile ( _, mess ) =
            if m.hideGoodFiles then
                List.length mess > 0
            else
                True

        asItem ( fileName, messages ) =
            Html.a
                [ Html.Attributes.class "list-group-item", onClick (OnSelectFile fileName) ]
                [ Html.span [ Html.Attributes.class "badge" ]
                    [ Html.text <| toString (List.length messages) ]
                , Html.text fileName
                ]
    in
    Html.div []
        [ Html.div [ Html.Attributes.class "checkbox" ]
            [ Html.label []
                [ Html.input
                    [ Html.Attributes.type_ "checkbox"
                    , Html.Attributes.checked m.hideGoodFiles
                    , onClick ToggleHideGoodFiles
                    ]
                    []
                , Html.text "Only show files with messages"
                ]
            ]
        , Html.hr [] []
        , case m.fileIndex of
            Just fileIndex ->
                Html.div
                    [ Html.Attributes.class "row"
                    , Html.Attributes.style [ ( "padding-top", "10px" ) ]
                    ]
                    [ Html.div [ Html.Attributes.class "col-md-6 col-sm-6" ]
                        [ Html.div [ Html.Attributes.class "list-group" ]
                            (fileIndex
                                |> List.filter allowFile
                                |> List.map asItem
                            )
                        ]
                    , Html.div [ Html.Attributes.class "col-md-6 col-sm-6" ]
                        [ if m.selectedFile == Nothing then
                            Html.div [] []
                          else
                            MessageList.view m.messageList |> Html.map MessageListMsg
                        ]
                    ]

            _ ->
                Html.div [] []
        ]

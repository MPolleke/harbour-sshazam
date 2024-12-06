import QtQuick 2.0
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0
import "../modules/Opal/SmartScrollbar"

Page {
    allowedOrientations: Orientation.All

    SilicaListView {
        id: listView
        anchors {
            fill: parent
            bottomMargin: Theme.paddingLarge
        }
        spacing: Theme.paddingLarge
        model: ListModel {
            function loadHistory() {
                py.trackFound = false
                clear()
                appConfiguration.getHistory().forEach(function (record, i) {
                    py.loadHistoryRecord(record, function(t,s,se,d) {
                        append({ arrIndex: i, raw: record, title: t, subtitle: s, sections: se, date: d })
                    })
                })
            }
            Component.onCompleted: loadHistory()
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Reload history")
                onClicked: listView.model.loadHistory()
            }
        }

        header: Column {
            width: parent.width
            PageHeader { title: "SShazam" }

            Item {
                height: Screen.width-Theme.horizontalPageMargin*2
                width: height
                anchors.horizontalCenter: parent.horizontalCenter

                IconButton {
                    icon.source: "image://theme/icon-l-music"
                    anchors.centerIn: parent
                    icon.fillMode: Image.Stretch
                    icon.sourceSize.height: height-Theme.paddingLarge*2
                    icon.sourceSize.width: height-Theme.paddingLarge*2
                    height: parent.height - Theme.itemSizeLarge
                    width: height

                    Behavior on height { NumberAnimation { duration: 500 } }

                    Timer {
                        id: animationTimer
                        property bool animating: false
                        repeat: true
                        interval: 500
                        onTriggered: {
                            if (animating) parent.height = parent.parent.height
                            else parent.height = parent.parent.height - Theme.itemSizeLarge
                            animating = !animating
                        }
                    }

                    onClicked: {
                        if (animationTimer.running) return
                        animationTimer.start()
                        if (py.trackFound) listView.model.loadHistory()
                        py.recognize(function() {
                            animationTimer.stop()
                            height = parent.height - Theme.itemSizeLarge
                        })
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.highlightBackgroundColor
                        opacity: 0.5
                        z: -1
                        radius: width*0.5
                    }
                }
            }

            Label {
                text: switch (py.recognitionState) {
                      case 2: return qsTr("Recording")
                      case 3: return qsTr("Processing")
                      case 4: return qsTr("Almost done")
                      default: return qsTr("Loading")
                      }
                visible: animationTimer.running && py.recognitionState > 0
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeMedium
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                horizontalAlignment: Qt.AlignHCenter

                opacity: visible ? 1 : 0
                height: visible ? implicitHeight : 0
                Behavior on opacity { FadeAnimation {} }
                Behavior on height { NumberAnimation { duration: 200 } }
                onHeightChanged: listView.positionViewAtBeginning()
            }

            SectionHeader {
                text: qsTr("Recognition Result")
                visible: py.trackFound
                opacity: visible ? 1 : 0
                height: visible ? implicitHeight : 0
                Behavior on opacity { FadeAnimation {} }
                Behavior on height { NumberAnimation { duration: 200 } }
                onHeightChanged: listView.positionViewAtBeginning()
            }

            BackgroundItem {
                contentHeight: Theme.itemSizeExtraLarge
                visible: py.trackFound
                opacity: visible ? 1 : 0
                height: visible ? implicitHeight : 0
                Behavior on opacity { FadeAnimation {} }
                Behavior on height { NumberAnimation { duration: 200 } }
                onHeightChanged: listView.positionViewAtBeginning()

                Column {
                    width: parent.width - Theme.horizontalPageMargin*2
                    anchors.horizontalCenter: parent.horizontalCenter
                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        text: py.title
                    }
                    Label {
                        width: parent.width
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                        text: py.subtitle
                    }
                }

                onClicked: pageStack.push(Qt.resolvedUrl('SongPage.qml'), { title: py.title, subtitle: py.subtitle, sections: py.sections })
            }

            SectionHeader {
                text: qsTr("History")
                opacity: listView.model.count > 0 ? 1 : 0
                Behavior on opacity { FadeAnimator {} }
            }
        }

        SmartScrollbar {
            flickable: listView

            readonly property int scrollIndex: !!flickable ?
                flickable.indexAt(flickable.contentX, flickable.contentY) : -1
            readonly property var scrollData: !!flickable ? listView.model.get(scrollIndex+1) : null

            //smartWhen: !!flickable ? !!flickable.itemAt(flickable.contentX, flickable.contentY) : false
            text: "%1 / %2".arg(scrollIndex + 2).arg(flickable.count)
            description: (!!scrollData && !!scrollData.title) ? Format.formatDate(scrollData.date, Formatter.TimepointRelative) : ''
        }

        delegate: ListItem {
            id: listItem
            ListView.onAdd: AddAnimation { target: listItem }
            contentHeight: historyItem.height

            Item {
                id: historyItem
                width: parent.width - Theme.horizontalPageMargin*2
                anchors.horizontalCenter: parent.horizontalCenter
                height: Math.max(children[0].height, children[1].height)
                Column {
                    width: parent.width - (date ? (dateLbl.width + Theme.paddingLarge) : 0)
                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        text: title
                        //text: title + " " + Theme.highlightText(subtitle, subtitle, Theme.secondaryColor)
                    }
                    Label {
                        width: parent.width
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                        text: subtitle
                    }
                }
                Label {
                    id: dateLbl
                    anchors.right: parent.right
                    color: Theme.secondaryColor
                    text: date == -1 ? '' : Format.formatDate(new Date(date), Formatter.TimepointRelative)
                }
            }

            onClicked: pageStack.push(Qt.resolvedUrl('SongPage.qml'), { title: title, subtitle: subtitle, sections: sections })

            menu: Component { ContextMenu {
                    MenuItem {
                        text: qsTr("Remove")
                        onClicked: {
                            var history = appConfiguration.getHistory()
                            if (history.length === listView.model.length) {
                                listView.model.loadHistory()
                                shared.showError(qsTr("Could not remove record. Please try again. History was outdated"))
                                return
                            }
                            history.splice(arrIndex, 1)
                            appConfiguration.setHistory(history)
                            listView.model.loadHistory()
                        }
                    }
                } }
        }
    }
}

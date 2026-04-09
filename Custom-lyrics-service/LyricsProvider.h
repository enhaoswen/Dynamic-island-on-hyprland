#pragma once

#include <QObject>
#include <QString>

class LyricsProvider : public QObject {
  Q_OBJECT

public:
  explicit LyricsProvider(QObject *parent = nullptr);
  Q_INVOKABLE void fetchCurrentSong();
  Q_INVOKABLE QString currentTitle() const;
  Q_INVOKABLE QString currentArtist() const;

private:
  QString m_currentTitle;
  QString m_currentArtist;
};

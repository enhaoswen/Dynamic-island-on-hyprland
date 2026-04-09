#include <QDebug>
#include <QProcess>

#include "LyricsProvider.h"

static QString decodeOctalEscapes(const QString &input) {
  QByteArray inputBytes = input.toUtf8();
  QByteArray resultBytes;

  for (int i = 0; i < inputBytes.length(); i++) {
    if (inputBytes[i] == '\\' && i + 3 < inputBytes.length()) {
      QByteArray octal = inputBytes.mid(i + 1, 3);
      bool ok;
      int byte = octal.toInt(&ok, 8);
      if (ok) {
        resultBytes.append(static_cast<char>(byte));
        i += 3;
        continue;
      }
    }
    resultBytes.append(inputBytes[i]);
  }

  return QString::fromUtf8(resultBytes);
}

LyricsProvider::LyricsProvider(QObject *parent) : QObject(parent) {}

QString LyricsProvider::currentTitle() const {
  return m_currentTitle;
}

QString LyricsProvider::currentArtist() const {
  return m_currentArtist;
}

void LyricsProvider::fetchCurrentSong() {
  QProcess process;
  process.start("busctl",
                {"--user", "get-property", "org.mpris.MediaPlayer2.playerctld",
                 "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player",
                 "Metadata"});
  process.waitForFinished(500);

  QString output = QString::fromUtf8(process.readAllStandardOutput());

  QString title, artist;

  int titlePos = output.indexOf("xesam:title");
  if (titlePos != -1) {
    int start = output.indexOf("\"", titlePos + 12);
    int end = output.indexOf("\"", start + 1);
    title = output.mid(start + 1, end - start - 1);
  }

  int artistPos = output.indexOf("xesam:artist");
  if (artistPos != -1) {
    int start = output.indexOf("\"", artistPos + 13);
    int end = output.indexOf("\"", start + 1);
    artist = output.mid(start + 1, end - start - 1);
  }

  m_currentTitle = decodeOctalEscapes(title);
  m_currentArtist = decodeOctalEscapes(artist);

  if (!m_currentTitle.isEmpty()) {
    qDebug() << "Title:" << m_currentTitle << "Artist:" << m_currentArtist;
  }
}

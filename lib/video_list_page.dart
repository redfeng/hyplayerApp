import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hyplayer/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyplayer/player_page.dart';
import 'package:http/http.dart' as http;

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  List<Map<String, String>> _videos = [];
  final String _storageKey = 'video_list_v2';

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List list = jsonDecode(data);
      setState(() {
        _videos = List<Map<String, String>>.from(
          list.map((e) => Map<String, String>.from(e)),
        );
      });
    } else {
      // 首次加载可填充默认数据
      setState(() {
        _videos = [
          {
            'title': 'BipBop (HLS)',
            'cover': 'https://via.placeholder.com/120x68.png?text=HLS',
            'url': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          },
          {
            'title': 'Big Buck Bunny (MP4)',
            'cover': 'https://via.placeholder.com/120x68.png?text=MP4',
            'url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          },
        ];
      });
      _saveVideos();
    }
  }

  Future<void> _saveVideos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_videos));
  }

  void _addVideo(Map<String, String> video) {
    setState(() {
      _videos.insert(0, video); // Insert at the beginning
    });
    _saveVideos();
  }

  void _removeVideo(int index) {
    setState(() {
      _videos.removeAt(index);
    });
    _saveVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频列表')),
      body: _videos.isEmpty
          ? const Center(child: Text('暂无视频, 点击右下角按钮添加'))
          : ListView.separated(
              itemCount: _videos.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final video = _videos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        video['cover']!,
                        width: 80,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 80,
                          height: 45,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    title: Text(
                      video['title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      video['url']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        _removeVideo(index);
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerPage(videoUrl: video['url']!),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVideoDialog,
        child: const Icon(Icons.add),
        tooltip: '添加视频',
      ),
    );
  }

  Future<void> _showAddVideoDialog() async {
    final textController = TextEditingController();
    // Use a stateful builder to manage the loading state within the dialog
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while loading
      builder: (context) {
        bool isLoading = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('添加新视频'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('正在解析...')
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: '粘贴抖音或B站的分享链接',
                        errorText: errorMessage,
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('确认'),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final url = textController.text;
                          if (url.isEmpty) return;

                          setDialogState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final response = await http.post(
                              Uri.parse('$proxyServerUrl/api/parse_video'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({'url': url}),
                            );

                            if (response.statusCode == 200) {
                              final data = jsonDecode(utf8.decode(response.bodyBytes));
                              _addVideo({
                                'title': data['title'] ?? '无标题',
                                'cover': data['coverUrl'] ?? '',
                                'url': data['videoUrl'] ?? '',
                              });
                              if (mounted) Navigator.pop(context);
                            } else {
                              final errorData = jsonDecode(response.body);
                              setDialogState(() {
                                isLoading = false;
                                errorMessage = errorData['detail'] ?? '未知错误';
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorMessage = '请求失败: ${e.toString()}';
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
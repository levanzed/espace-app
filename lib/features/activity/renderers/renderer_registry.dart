import 'activity_renderer.dart';
import 'assign_renderer.dart';
import 'bigbluebuttonbn_renderer.dart';
import 'book_renderer.dart';
import 'chat_renderer.dart';
import 'choice_renderer.dart';
import 'data_renderer.dart';
import 'feedback_renderer.dart';
import 'folder_renderer.dart';
import 'forum_renderer.dart';
import 'generic_renderer.dart';
import 'glossary_renderer.dart';
import 'h5pactivity_renderer.dart';
import 'imscp_renderer.dart';
import 'label_renderer.dart';
import 'lesson_renderer.dart';
import 'lti_renderer.dart';
import 'page_renderer.dart';
import 'quiz_renderer.dart';
import 'resource_renderer.dart';
import 'scorm_renderer.dart';
import 'subsection_renderer.dart';
import 'url_renderer.dart';
import 'wiki_renderer.dart';
import 'workshop_renderer.dart';

class RendererRegistry {
  RendererRegistry._();

  static final Map<String, ActivityRenderer> _renderers = {
    'assign': const AssignRenderer(),
    'quiz': const QuizRenderer(),
    'forum': const ForumRendererAdapter(),
    'resource': const ResourceRenderer(),
    'folder': const FolderRenderer(),
    'url': const UrlRenderer(),
    'page': const PageRenderer(),
    'book': const BookRenderer(),
    'label': const LabelRenderer(),
    'choice': const ChoiceRenderer(),
    'feedback': const FeedbackRenderer(),
    'glossary': const GlossaryRenderer(),
    'lesson': const LessonRenderer(),
    'wiki': const WikiRenderer(),
    'workshop': const WorkshopRenderer(),
    'scorm': const ScormRenderer(),
    'h5pactivity': const H5pActivityRenderer(),
    'chat': const ChatRenderer(),
    'data': const DataRenderer(),
    'lti': const LtiRenderer(),
    'ltiexternaltool': const LtiRenderer(),
    'bigbluebuttonbn': const BigBlueButtonRenderer(),
    'imscp': const ImscpRenderer(),
    'subsection': const SubsectionRenderer(),
  };

  static ActivityRenderer get(String modname) {
    return _renderers[modname] ?? const GenericRenderer();
  }

  static Iterable<String> get supportedModnames => _renderers.keys;
}

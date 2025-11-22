import '../models/job_template.dart';
import '../services/api_client.dart';
import '../services/job_template_service.dart';

class JobTemplateRepo {
  final JobTemplateService _jobTemplateService;

  JobTemplateRepo(ApiClient apiClient)
      : _jobTemplateService = JobTemplateService(apiClient);

  Future<List<JobTemplate>> getAll() {
    return _jobTemplateService.getAll();
  }

  Future<JobTemplate> getById(String id) {
    return _jobTemplateService.getById(id);
  }

  Future<JobTemplate> create(JobTemplate template) {
    return _jobTemplateService.create(template);
  }

  Future<JobTemplate> update(String id, JobTemplate template) {
    return _jobTemplateService.update(id, template);
  }

  Future<void> delete(String id) {
    return _jobTemplateService.delete(id);
  }
}


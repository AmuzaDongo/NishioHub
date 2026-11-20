import { MainLayout } from "@/components/layout/main-layout";
import { usePlatform } from "@/lib/platform-context";
export default function MentorGuidelines() {
  const platform = usePlatform();
  return (
    <MainLayout>
      <article className='mx-auto max-w-3xl space-y-7 px-5 py-10'>
        <header>
          <h1 className='text-3xl font-extrabold'>Mentorship Guidelines</h1>
          <p className='mt-2 text-sm'>
            Code of Conduct and Child Safeguarding Policy · Version 2026-11-15
          </p>
        </header>
        <section id='conduct' className='scroll-mt-24'>
          <h2 className='mb-3 text-xl font-bold'>Mentorship Code of Conduct</h2>
          <ul className='list-disc space-y-3 pl-5 text-sm'>
            <li>
              Treat learners respectfully and inclusively. Harassment,
              discrimination, exploitation and sexual or romantic approaches to
              learners are prohibited.
            </li>
            <li>
              Represent your qualifications and experience honestly. Set clear
              learning goals and keep commitments and professional boundaries.
            </li>
            <li>
              Protect personal information. Do not publish learner
              conversations, images or contact details without appropriate
              permission.
            </li>
            <li>
              Use the platform’s agreed mentorship channels. Do not pressure
              learners to send money, gifts, credentials or sensitive personal
              information.
            </li>
            <li>
              Report concerning conduct to the platform team and cooperate with
              review. Approval may be reconsidered if these standards are
              breached.
            </li>
          </ul>
        </section>
        <section id='safeguarding' className='scroll-mt-24'>
          <h2 className='mb-3 text-xl font-bold'>Child Safeguarding Policy</h2>
          <ul className='list-disc space-y-3 pl-5 text-sm'>
            <li>
              Prioritize a child’s safety, dignity and wellbeing. Keep all
              guidance age-appropriate.
            </li>
            <li>
              Coordinate mentorship of minors with their school, guardian or
              approved programme coordinator. Do not arrange private,
              unsupervised meetings or move a child to personal messaging
              channels.
            </li>
            <li>
              Never ask a child for private images, secrets, passwords, location
              details or contact unrelated to the learning activity.
            </li>
            <li>
              Respond calmly to safeguarding concerns. Do not promise secrecy;
              share concerns promptly with the appropriate platform safeguarding
              contact and school or guardian as appropriate.
            </li>
            <li>
              If someone faces immediate danger, seek help from the relevant
              local emergency services. Use the platform support channel to
              report the incident as well.
            </li>
          </ul>
        </section>
        <section>
          <h2 className='mb-3 text-xl font-bold'>
            Documents & Application Review
          </h2>
          <p className='text-sm'>
            Application documents are accessible only to the applicant and
            authorized platform reviewers. Submit accurate information and
            references who have agreed to be contacted. For questions,
            corrections or a document deletion request, contact{" "}
            <a
              className='text-violet-700 underline'
              href={`mailto:${platform.support_email}`}
            >
              {platform.support_email}
            </a>
            .
          </p>
        </section>
      </article>
    </MainLayout>
  );
}